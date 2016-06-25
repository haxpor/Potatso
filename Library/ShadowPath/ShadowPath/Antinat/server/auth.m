/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-04 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#include "antinat.h"
#ifdef HAVE_CRYPT_H
#include <crypt.h>
#endif
#ifdef HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef HAVE_SHADOW_H
#include <shadow.h>
#endif

static BOOL
auth_config_getpw (config_t * conf, const char *username, char **passwd)
{
	const char *realpasswd;
	char *tmp;
	BOOL authed;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	authed = FALSE;
	realpasswd = NULL;
	realpasswd = config_getUser (conf, username);
#ifdef WITH_DEBUG
	if (realpasswd)
		sprintf (szDebug, "Found user, has hash %s", realpasswd);
	else
		sprintf (szDebug, "Username not found - %s", username);
	DEBUG_LOG (szDebug);
#endif
	if (realpasswd) {
		tmp = (char *) malloc (strlen (realpasswd) + 1);
		if (tmp != NULL) {
			strcpy (tmp, realpasswd);
			*passwd = tmp;
			return TRUE;
		}
	}
	return FALSE;
}

static BOOL
auth_getPasswordByUsername (config_t * conf, const char *username,
							char **passwd)
{
	/* This is a placeholder so we can support more datasources. */
	return auth_config_getpw (conf, username, passwd);
}


static const char lets[] =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwyxz0123456789+/";

static BOOL
auth_chap_gen_challenge (char *data, int len)
{
	int i;
	for (i = 0; i < len; i++) {
		data[i] = lets[rand () % 64];
	}
	return TRUE;
}

static BOOL
auth_chap_send_fail (conn_t * conn)
{
	char str[16];
	str[0] = 0x01;
	str[1] = 0x01;
	str[2] = 0x00;
	str[3] = 0x01;
	str[4] = 0x01;
	return conn_sendData (conn, str, 5);
}

static BOOL
auth_chap_send_ok (conn_t * conn)
{
	char str[16];
	str[0] = 0x01;
	str[1] = 0x01;
	str[2] = 0x00;
	str[3] = 0x01;
	str[4] = 0x00;
	return conn_sendData (conn, str, 5);
}

/* This is an internal client library function. */
int _an_socks5_hmacmd5_chap (const unsigned char *, int,
							 const char *, unsigned char *);


static BOOL
auth_hmacmd5_chap (const unsigned char *challenge, int challen,
				   const char *passwd, unsigned char **response, int *resplen)
{
	unsigned char *respbuf;
	respbuf = (unsigned char *) malloc (20);
	if (respbuf == NULL)
		return FALSE;
	if (_an_socks5_hmacmd5_chap (challenge, challen,
								 passwd, respbuf) == AN_ERROR_SUCCESS) {
		*response = respbuf;
		*resplen = 16;
		return TRUE;
	}
	free (respbuf);
	return FALSE;
}

BOOL
auth_chap (conn_t * conn)
{
	unsigned char version;
	unsigned char tmpch;
	unsigned char navas;
	unsigned char att[10];
	char challenge[100];
	char username[256];
	int thealgo;
	unsigned char *correctresp;
	unsigned char *gotresp;
	char *passwd;
	int resplen;
	BOOL authed;
	BOOL finished;
	BOOL sentChallenge;
	BOOL sendChallenge;
	int sendAlgo;
	int i, j;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	finished = FALSE;

	authed = FALSE;
	gotresp = NULL;
	correctresp = NULL;
	passwd = NULL;
	sentChallenge = FALSE;
	thealgo = -1;
	strcpy (username, "");

	while (!finished) {
		sendChallenge = FALSE;
		sendAlgo = -1;
		if (!conn_getChar (conn, &version))
			return FALSE;
		if (version != 1)
			return FALSE;
		if (!conn_getChar (conn, &navas))
			return FALSE;
		for (i = 0; i < navas; i++) {
			if (!conn_getSlab (conn, (char *) &att, 2))
				return FALSE;
			/* Documented:
			 * 0- status
			 * 1- Text-message
			 * 2- User-identity
			 * 3- Challenge
			 * 4- Response
			 * 5- Charset
			 * 16-Identifier
			 * 17-Algorithms
			 */
#ifdef WITH_DEBUG
			sprintf (szDebug, "recved att %x data length %i", att[0], att[1]);
			DEBUG_LOG (szDebug);
#endif
			switch (att[0]) {
			case 2:
				if (!conn_getSlab (conn, username, att[1]))
					goto barfed;
#ifdef WITH_DEBUG
				sprintf (szDebug, "Set username to %s", username);
				DEBUG_LOG (szDebug);
#endif
				if (!sentChallenge)
					sendChallenge = TRUE;
				break;
			case 4:
				gotresp = (unsigned char *) malloc (att[1] + 1);
				if (gotresp == NULL) {
					auth_chap_send_fail (conn);
					goto barfed;
				}
				if (!conn_getSlab (conn, (char *) gotresp, att[1])) {
					auth_chap_send_fail (conn);
					goto barfed;
				}
				if (thealgo < 0) {
					auth_chap_send_fail (conn);
					goto barfed;
				}

				if (!auth_getPasswordByUsername
					(conn->conf, username, &passwd)) {
					auth_chap_send_fail (conn);
					goto barfed;
				}
				switch (thealgo) {
				case 0x85:		/* HMAC-MD5 */
					if (auth_hmacmd5_chap
						((unsigned char *) challenge, 64, passwd,
						 &correctresp, &resplen) == FALSE) {
						auth_chap_send_fail (conn);
						goto barfed;
					}
					break;
				default:
					auth_chap_send_fail (conn);
					goto barfed;
					break;
				}

				if (resplen != att[1]) {
					/* If the lengths differ, so do the responses */
					auth_chap_send_fail (conn);
					goto barfed;
				}
				if (memcmp (correctresp, gotresp, resplen) == 0) {
					auth_chap_send_ok (conn);
					conn_setUser (conn, username);
					conn_setPass (conn, passwd);
					conn->authsrc = AUTH_CONFIG;
					authed = TRUE;
					goto barfed;
				} else {
					auth_chap_send_fail (conn);
					goto barfed;
				}
				break;
			case 0x11:
				for (j = 0; j < att[1]; j++) {
					if (!conn_getChar (conn, &tmpch))
						goto barfed;
					if (sendAlgo < 0) {
						if (tmpch == 0x85)
							sendAlgo = tmpch;
					}

				}
				if (sendAlgo < 0)
					sendAlgo = -2;
				if (!sentChallenge)
					sendChallenge = TRUE;
				break;
			}
		}
		if (sendAlgo == -2) {
			auth_chap_send_fail (conn);
			goto barfed;
		}
		att[0] = 0x01;
		att[1] = 0x00;
		if (sendChallenge)
			att[1]++;
		if (sendAlgo >= 0)
			att[1]++;
		if (!conn_sendData (conn, (char *) att, 2))
			goto barfed;
		if (sendAlgo >= 0) {
			att[0] = 0x11;
			att[1] = 0x01;
			att[2] = sendAlgo;
			if (!conn_sendData (conn, (char *) att, 3))
				goto barfed;
			thealgo = sendAlgo;
		}
		if (sendChallenge) {
			auth_chap_gen_challenge (challenge, 64);
			att[0] = 0x03;
			att[1] = 0x40;
			if (!conn_sendData (conn, (char *) att, 2))
				goto barfed;
			if (!conn_sendData (conn, (char *) challenge, 64))
				goto barfed;
		}
	}

  barfed:
	if (gotresp != NULL)
		free (gotresp);
	if (correctresp != NULL)
		free (correctresp);
	if (passwd != NULL)
		free (passwd);
#ifdef WITH_DEBUG
	if (authed) {
		DEBUG_LOG ("authenticated successfully");
	} else {
		DEBUG_LOG ("failed authentication");
	}
#endif
	return authed;
}

/* TODO: Implement win32 native user authentication */
#ifndef _WIN32_
static BOOL
auth_local (const char *username, const char *passwd)
{
	char csalt[12];
	char *realpasswd;
	char pwhash[50];
	BOOL authed;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
#ifdef HAVE_GETSPNAM
	struct spwd *shad_pw;
#ifdef HAVE_GETSPNAM_R
	struct spwd realspwd;
#endif
#else
#ifdef HAVE_GETPWNAM
	struct passwd *pw_pw;
#ifdef HAVE_GETPWNAM_R
	struct passwd realpwd;
#endif
#endif
#endif
#if defined(HAVE_GETSPNAM_R)||(HAVE_GETPWNAM_R)
	char buf[1024];
#endif
#if (defined(HAVE_CRYPT_CRYPT_R)||defined(HAVE_CRYPT_R))&&(!defined(BROKEN_CRYPT_R))
	struct crypt_data cd;
#endif

#ifdef HAVE_GETSPNAM
	shad_pw = NULL;
#endif
	authed = FALSE;
	realpasswd = NULL;
#ifdef HAVE_GETSPNAM			/* The system supports shadow password */
#ifndef HAVE_GETSPNAM_R			/* System has no reentrant shadow functions */
	os_mutex_lock (&getspnam_lock);
	shad_pw = getspnam (username);
#else /* System has reentrant shadow functions */
#ifdef BROKEN_GETSPNAM			/* System has Solaris-style shadow functions */
	shad_pw = getspnam_r (username, &realspwd, buf, sizeof (buf));
#else /* System has Linux-style shadow functions */
	getspnam_r (username, &realspwd, buf, sizeof (buf), &shad_pw);
#endif /* BROKEN_GETSPNAM */
#endif /* HAVE_GETSPNAM_R */
	if (shad_pw) {
		realpasswd = (char *) malloc (strlen (shad_pw->sp_pwdp) + 1);
		if (realpasswd)
			strcpy (realpasswd, shad_pw->sp_pwdp);
	}
#ifndef HAVE_GETSPNAM_R			/* No reentrant shadow functions */
	os_mutex_unlock (&getspnam_lock);
#endif
#else /* No shadow - try passwd */
#ifdef HAVE_GETPWNAM			/* Do we have passwd functions */
#ifndef HAVE_GETPWNAM_R			/* We have no reentrant passwd functions */
	os_mutex_lock (&getpwnam_lock);
	pw_pw = getpwnam (username);
#else /* We have reentrant passwd functions */
#ifdef BROKEN_GETPWNAM			/* System has Solaris-style passwd functions */
	pw_pw = getpwnam_r (username, &realpwd, buf, sizeof (buf));
#else /* System has Linux-style passwd functions */
	getpwnam_r (username, &realpwd, buf, sizeof (buf), &pw_pw);
#endif /* BROKEN_GETPWNAM */
#endif /* HAVE_GETPWNAM_R */
	if (pw_pw) {
		realpasswd = (char *) malloc (strlen (pw_pw->pw_passwd) + 1);
		if (realpasswd)
			strcpy (realpasswd, pw_pw->pw_passwd);
	}
#ifndef HAVE_GETPWNAM_R			/* No reentrant passwd functions */
	os_mutex_unlock (&getpwnam_lock);
#endif /* HAVE_GETPWNAM_R */
#endif /* HAVE_GETPWNAM */
#endif /* HAVE_GETSPNAM */
#ifdef WITH_DEBUG
	if (realpasswd) {
		sprintf (szDebug, "Found user, has hash %s", realpasswd);
		DEBUG_LOG (szDebug);
	} else
		DEBUG_LOG ("Username not found");
#endif
	if (realpasswd) {
		csalt[0] = realpasswd[0];
		csalt[1] = realpasswd[1];
		csalt[2] = '\0';
		if (strcmp (csalt, "$1") == 0) {
			strncpy (csalt, realpasswd, 11);
			csalt[11] = '\0';
		}
		/* Apparently, crypt_r can't auth against non-MD5 passwds :( */
#if (defined(HAVE_CRYPT_CRYPT_R)||defined(HAVE_CRYPT_R))&&(!defined(BROKEN_CRYPT_R))
		strcpy (pwhash, crypt_r (passwd, csalt, &cd));
		if (strcmp (pwhash, realpasswd) == 0) {
			authed = TRUE;
		} else {
#ifdef WITH_DEBUG
			DEBUG_LOG ("Couldn't authenticate with crypt_r.  Trying crypt.");
#endif
#endif
			os_mutex_lock (&crypt_lock);
			strcpy (pwhash, crypt (passwd, csalt));
			os_mutex_unlock (&crypt_lock);
			if (strcmp (pwhash, realpasswd) == 0) {
				authed = TRUE;
			}
#if (defined(HAVE_CRYPT_CRYPT_R)||defined(HAVE_CRYPT_R))&&(!defined(BROKEN_CRYPT_R))
		}
#endif
	}

	if (realpasswd)
		free (realpasswd);
	return authed;
}
#endif

#ifdef _WIN32_

#ifndef LOGON32_LOGON_NETWORK
#define LOGON32_LOGON_NETWORK 3
#endif

#ifndef LOGON32_PROVIDER_DEFAULT
#define LOGON32_PROVIDER_DEFAULT 0
#endif

typedef BOOL (*LogonUserProc) (LPTSTR, LPTSTR, LPTSTR, DWORD, DWORD, PHANDLE);
static BOOL
auth_local_win32 (const char *username, const char *passwd)
{
	BOOL ret;
	HANDLE tok;
	HINSTANCE hDll;
	LogonUserProc lu;
#ifdef WITH_DEBUG
	DWORD err;
#endif

	hDll = LoadLibrary ("advapi32.dll");
	if (hDll == NULL) {
#ifdef WITH_DEBUG
		DEBUG_LOG
			("Local authentication cannot be supported on this build of Windows.");
#endif
		return FALSE;
	}

	lu = (LogonUserProc) GetProcAddress (hDll, "LogonUserA");

	if (lu == NULL) {
#ifdef WITH_DEBUG
		DEBUG_LOG
			("Local authentication cannot be supported on this build of Windows.");
#endif
		FreeLibrary (hDll);
		return FALSE;
	}

	ret =
		lu ((LPTSTR) username, NULL, (LPTSTR) passwd, LOGON32_LOGON_NETWORK,
			LOGON32_PROVIDER_DEFAULT, &tok);
	if (ret) {
		/* It worked? */
		CloseHandle (tok);
		FreeLibrary (hDll);
		return TRUE;
	}

	FreeLibrary (hDll);

#ifdef WITH_DEBUG
	err = GetLastError ();
	if (err == ERROR_PRIVILEGE_NOT_HELD) {
		DEBUG_LOG
			("Cannot locally authenticate without having 'Act as part of the operating system' user right");
	}
#endif

	return FALSE;
}
#endif

static BOOL
auth_authUsernamePassword (conn_t * conn, const char *username,
						   const char *passwd)
{
	config_t *conf;
	char *correctpw;
	BOOL authed;
	conf = conn->conf;
	/* This is a placeholder for more auth mechanisms. */
	if (config_allowLocalUsers (conf)) {
#ifndef _WIN32_
		if (auth_local (username, passwd)) {
			conn->authsrc = AUTH_LOCAL;
			return TRUE;
		}
#else
		if (auth_local_win32 (username, passwd)) {
			conn->authsrc = AUTH_LOCAL;
			return TRUE;
		}
#endif
	}
	authed = FALSE;
	if (auth_config_getpw (conf, username, &correctpw)) {
		if (strcmp (correctpw, passwd) == 0) {
			authed = TRUE;
			conn->authsrc = AUTH_CONFIG;
		}
		free (correctpw);
	}
	return authed;
}

BOOL
auth_unpw (conn_t * conn)
{
	unsigned char version;
	unsigned char length;
	char username[260];
	char passwd[260];
	char rep[3];
	BOOL authed;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

	authed = FALSE;
	if (!conn_getChar (conn, &version))
		return FALSE;
	if (version != 1)
		return FALSE;
	if (!conn_getChar (conn, &length))
		return FALSE;

	/* getSlab null terminates */
	if (!conn_getSlab (conn, username, length))
		goto barfed;
	if (!conn_getChar (conn, &length))
		goto barfed;
	if (!conn_getSlab (conn, passwd, length))
		goto barfed;

	authed = auth_authUsernamePassword (conn, username, passwd);

  barfed:
	rep[0] = 0x01;
	if (authed) {
#ifdef WITH_DEBUG
		sprintf (szDebug, "User %s authenticated", username);
#endif
		rep[1] = '\0';
		conn_setUser (conn, username);
		conn_setPass (conn, passwd);
	} else {
#ifdef WITH_DEBUG
		sprintf (szDebug, "User %s NOT authenticated", username);
#endif
		rep[1] = 0x01;
	}
#ifdef WITH_DEBUG
	DEBUG_LOG (szDebug);
#endif
	conn_sendData (conn, rep, 2);
	return authed;
}
