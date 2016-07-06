/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#include <sys/types.h>
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_CTYPE_H
#include <ctype.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_LIMITS_H
#include <limits.h>
#endif
#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif
#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

static BOOL
socks4_sendResponse (conn_t * conn, char rep, unsigned long addr,
					 unsigned short port)
{
	char szResp[8];
	szResp[0] = 0x00;
	szResp[1] = rep;
	memcpy (&szResp[2], &port, 2);
	memcpy (&szResp[4], &addr, 4);
	conn_sendData (conn, szResp, 8);
	return TRUE;
}

static void
socks4_notifyclient (conn_t * conn, ANCONN s, SOCKADDR_IN * sout,
					 sl_t soutlen)
{
	int ret;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	if ((ret =
		 an_getsockname (s, (SOCKADDR *) sout,
						 soutlen)) == AN_ERROR_SUCCESS) {
#ifdef WITH_DEBUG
		sprintf(szDebug,"Told client %x:%i, ret %i",ntohl(sout->sin_addr.s_addr),sout->sin_port, ret);
		DEBUG_LOG(szDebug);
		DEBUG_LOG ("Bind succeeded, interface known");
#endif
		socks4_sendResponse (conn, 90, sout->sin_addr.s_addr, sout->sin_port);
	} else {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind succeeded, interface unknown");
#endif
		socks4_sendResponse (conn, 90, 0, 0);
	}
}

static BOOL
socks4_cmd_bind (conn_t * conn, chain_t * chain)
{
	ANCONN remote;
	SOCKET top;
	SOCKADDR *addr;
	sl_t addrlen;
	SOCKADDR_IN sout;
	SOCKADDR_IN clientside;
	SOCKADDR_IN *inaddy;
	sl_t soutlen;
	fd_set fds;
	struct timeval tv;
#ifdef WITH_DEBUG
	char szDebug[100];
#endif

	if (!ai_getSockaddr (&conn->dest, &addr, &addrlen))
		return FALSE;

#ifdef WITH_DEBUG
	sprintf (szDebug, "Socket family: %x", addr->sa_family);
	DEBUG_LOG (szDebug);
#endif
	remote = an_new_connection ();
	conn_setupchain (conn, remote, chain);

#ifdef WITH_DEBUG
	{
		SOCKADDR_IN *sin;
		sin = (SOCKADDR_IN *) addr;
		sprintf (szDebug, "Binding to %x:%i",
				 (unsigned int) htonl (sin->sin_addr.s_addr),
				 ntohs (sin->sin_port));
		DEBUG_LOG (szDebug);
	}
#endif
	/* FIXME: SOCKSv4 explicitly says that the input interface
	 * sould be used to validate any incoming requests...ie.,
	 * this stuff is who we *want* to connect to us. */
	if ((remote == NULL) ||
		(an_bind_tosockaddr (remote, (SOCKADDR *) addr, addrlen) !=
		 AN_ERROR_SUCCESS) || (an_listen (remote) != AN_ERROR_SUCCESS)) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind failed");
#endif
		an_close (remote);
		an_destroy (remote);
		socks4_sendResponse (conn, 91, 0, 0);
		free (addr);
		return FALSE;
	}
	socks4_notifyclient (conn, remote, (SOCKADDR_IN *) & clientside,
						 sizeof (clientside));

	top = conn->s;
	FD_ZERO (&fds);
	FD_SET (conn->s, &fds);
	top = AN_FD_SET (remote, &fds, top);
	tv.tv_sec = config_getMaxbindwait (conn->conf);
	tv.tv_usec = 0;
	select (top + 1, &fds, NULL, NULL, &tv);
	if (AN_FD_ISSET (remote, &fds)) {
		/* Now to wait for incoming connection */
		memset (&sout, 0, sizeof (sout));
		sout.sin_family = addr->sa_family;
		soutlen = sizeof (sout);
		if (an_accept (remote, (SOCKADDR *) & sout, soutlen) !=
			AN_ERROR_SUCCESS) {
			/* Whoa, accept() failed.  Better tell client */
			socks4_sendResponse (conn, 91, 0, 0);
			free (addr);
			an_close (remote);
			an_destroy (remote);
			return FALSE;
		}

		/* Verify incoming address */
		inaddy = (SOCKADDR_IN *) addr;
		/* Note: don't check ports... */
		if ((inaddy->sin_family != sout.sin_family)
			|| ((inaddy->sin_addr.s_addr != 0)
				&&
				(memcmp (&inaddy->sin_addr.s_addr, &sout.sin_addr.s_addr, 4)
				 != 0))) {

#ifdef WITH_DEBUG
			sprintf (szDebug, "Addresses mismatch - wanted %x got %x (%i %i)",
					 (unsigned int) inaddy->sin_addr.s_addr,
					 (unsigned int) sout.sin_addr.s_addr, inaddy->sin_family,
					 sout.sin_family);
			DEBUG_LOG (szDebug);
#endif
			socks4_sendResponse (conn, 91, 0, 0);
			an_close (remote);
			an_destroy (remote);
			free (addr);
			return FALSE;
		}
		free (addr);
		/* Tell client who just arrived */
		socks4_notifyclient (conn, remote, &sout, soutlen);

		log_log (conn, LOG_EVT_LOG, LOG_TYPE_CONNECTIONESTABLISHED, NULL);

		/* As with connect, start forwarding data. */
		conn_forwardData (conn, remote);
	} else {
		an_close (remote);
		an_destroy (remote);
		socks4_sendResponse (conn, 91, 0, 0);
		free (addr);
		return FALSE;
	}

	return TRUE;
}


static BOOL
socks4_cmd_conn (conn_t * conn, chain_t * chain)
{
	ANCONN remote;
	SOCKADDR *addr;
	sl_t addrlen;
	SOCKADDR_IN sout;
	sl_t soutlen;
	ai_getSockaddr (&conn->dest, &addr, &addrlen);
	remote = an_new_connection ();
	conn_setupchain (conn, remote, chain);

	if (an_connect_tosockaddr (remote, addr, addrlen) != AN_ERROR_SUCCESS) {
		socks4_sendResponse (conn, 91, 0, 0);
		free (addr);
		an_close (remote);
		an_destroy (remote);
		return FALSE;
	}
#ifdef WITH_DEBUG
	DEBUG_LOG ("Connected");
#endif
	free (addr);
	soutlen = sizeof (sout);
	if (an_getsockname (remote, (SOCKADDR *) & sout, soutlen) ==
		AN_ERROR_SUCCESS) {
		socks4_sendResponse (conn, 90, sout.sin_addr.s_addr, sout.sin_port);
	} else {
		/* In socks4, this is valid... */
		socks4_sendResponse (conn, 90, 0, 0);
	}
#ifdef WITH_DEBUG
	DEBUG_LOG ("Send response to client");
#endif
	log_log (conn, LOG_EVT_LOG, LOG_TYPE_CONNECTIONESTABLISHED, NULL);
	conn_forwardData (conn, remote);

	return TRUE;
}




BOOL
socks4_handler (conn_t * conn)
{
	unsigned char cmd;
	unsigned char tmp;
	char temp[5];
	unsigned long ulAddr;
	chain_t *chain;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

	if (!conn_getChar (conn, &cmd))
		return FALSE;

	conn->dest.address_type = AF_INET;
	if (!conn_getSlab (conn, temp, 2))
		return FALSE;
	conn->dest.port = *(unsigned short *) temp;
	if (!conn_getSlab (conn, temp, 4))
		return FALSE;
	ulAddr = ntohl (*(unsigned long *) temp);

	/* Read until receive a NULL and throw it away. */
	tmp = 0x01;
	while (tmp != 0x00) {
		if (!conn_getChar (conn, &tmp)) {
			return FALSE;
		}
	}

	if ((ulAddr > 0) && (ulAddr < 256)) {
		/* This is a SOCKS 4a request.  It has a piggybacked name 
		 * trailing after the request body */
		char hostname[128];
		unsigned int i;
		BOOL bHaveHostname;
		bHaveHostname = FALSE;
		for (i = 0; (i < sizeof (hostname) - 1); i++) {
			if (!conn_getChar (conn, (unsigned char *) &hostname[i])) {
				return FALSE;
			}
			if (hostname[i] == '\0') {
				bHaveHostname = TRUE;
				break;
			}
		}
		hostname[i] = '\0';
#ifdef WITH_DEBUG
		sprintf (szDebug, "Have hostname: %i, hostname: %s",
				 bHaveHostname, hostname);
		DEBUG_LOG (szDebug);
#endif
		if (!bHaveHostname)
			return FALSE;
		if (!conn_setDestHostname (conn, hostname)) {
			socks4_sendResponse (conn, 91, 0, 0);
			return FALSE;
		}

	} else {
		ai_setAddress_str (&conn->dest, (char *) temp, 4);
	}

	conn->socksop = cmd;
	if (!config_isallowed (conn->conf, conn, &chain)) {
		return FALSE;
	}


	switch (cmd) {
	case 0x01:					/* Connect */
		return socks4_cmd_conn (conn, chain);
		break;
	case 0x02:					/* Bind */
		return socks4_cmd_bind (conn, chain);
		break;
	default:
#ifdef WITH_DEBUG
		sprintf (szDebug, "No command %x", cmd);
		DEBUG_LOG (szDebug);
#endif
		socks4_sendResponse (conn, 91, 0, 0);
		return FALSE;
		break;
	}
}
