/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#ifdef HAVE_SIGNAL_H
#include <signal.h>
#endif
#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif
#ifdef HAVE_IO_H
#include <io.h>
#endif
#include <stdlib.h>
#include <stdio.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef _WIN32_
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif
#include <fcntl.h>
//#include "sock.h"

os_mutex_t crypt_lock;
os_mutex_t getpwnam_lock;
os_mutex_t getspnam_lock;
os_mutex_t localtime_lock;
os_mutex_t writerpipe_lock;

static SOCKET srv = INVALID_SOCKET;
static config_t *conf = NULL;
static char *config_content = NULL;
static int config_content_size = 0;
#ifndef _WIN32_
static BOOL runAsDaemon = FALSE;
#endif
#ifdef _WIN32_
static BOOL runAsApplication = FALSE;
#endif

static BOOL an_active;

static BOOL
linger (SOCKET s)
{
	struct linger lyes;
	/*
	   Linger - if the socket is closed, ensure that data is sent/
	   received right up to the last byte.  Don't stop just because
	   the connection is closed.
	 */
	lyes.l_onoff = 1;
	lyes.l_linger = 10;
	setsockopt (s, SOL_SOCKET, SO_LINGER, (char *) &lyes, sizeof (lyes));
	return TRUE;
}

static BOOL
startServer (unsigned short nPort, unsigned long nIP)
{
	SOCKADDR_IN sin;
	int ret;
	unsigned int yes;

	yes = TRUE;

	/* Grab a place to listen for connections. */
	srv = socket (AF_INET, SOCK_STREAM, 0);
	if (srv < 0) {
		return FALSE;
	}

	linger (srv);

	/* If this server has been restarted, don't wait for the old
	 * one to disappear completely */
	setsockopt (srv, SOL_SOCKET, SO_REUSEADDR, (char *) &yes, sizeof (yes));
    setsockopt (srv, SOL_SOCKET, SO_NOSIGPIPE, (char *) &yes, sizeof (yes));

	memset (&sin, 0, sizeof (sin));
	sin.sin_family = AF_INET;
	sin.sin_port = htons (nPort);

	sin.sin_addr.s_addr = nIP;
	ret = bind (srv, (SOCKADDR *) & sin, sizeof (sin));
	if (ret < 0) {
		return FALSE;
	}

	/* Start listening for incoming connections. */
	ret = listen (srv, 1024);
	if (ret == 0)
		return TRUE;
	return FALSE;
}

/*
This big messy function processes each incoming request.
*/
BOOL
HandleRequest ()
{
	SOCKET cli;
	conn_t *conn;
	os_thread_t thr;
	os_thread_init (&thr);

	/* Accept an incoming request, or wait till one arrives. */
	cli = accept (srv, NULL, NULL);
	if (cli == INVALID_SOCKET) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Accept barfed");
#endif
		return FALSE;
	}
	linger (cli);
	config_reference (conf);
	conn = (conn_t *) malloc (sizeof (conn_t));
	if (conn) {
		conn_init_tcp (conn, conf, cli);
		if (os_thread_exec (&thr, ChildThread, conn)) {
			os_thread_detach (&thr);
			return TRUE;
		}
		conn_close (conn);
	}
	closesocket (cli);
	config_dereference (conf);

#ifdef WITH_DEBUG
	DEBUG_LOG ("Couldn't allocate memory or create thread");
#endif

	return FALSE;
}


/*
UNIX trivia - when is a problem a problem?  When you don't ignore it.
If you do nothing, well, you're not being ignorant enough.  You have
to be explicitly ignorant.
*/
void
ignorer (int x)
{
	signal (x, ignorer);
}

void closeup (int x);

void
reloadconfig (int x)
{
	unsigned long ip;
	unsigned short port;
	if (conf) {
		ip = config_getInterface (conf);
		port = config_getPort (conf);
		config_dereference (conf);
	} else {
		/* Must be invalid */
		ip = 0;
		port = 0;
	}
	conf = (config_t *) malloc (sizeof (config_t));
    conf->users = NULL;
    conf->chains = NULL;
	if (!loadconfig (conf, config_content, config_content_size)) {
#ifdef _WIN32_
		MessageBox (NULL, "Could not open configuration file.", "Antinat",
					48);
#else
		printf ("Could not open configuration file.");
#endif
		free (conf);
		exit (EXIT_FAILURE);
	}
	log_log (NULL, LOG_EVT_SERVERRESTART, 0, conf);
	if ((config_getPort (conf) != port) || (config_getInterface (conf) != ip)) {
		if (srv != INVALID_SOCKET)
			closesocket (srv);
		srv = INVALID_SOCKET;
		if (!startServer
			((unsigned short) config_getPort (conf),
			 (unsigned int) config_getInterface (conf))) {
#ifndef _WIN32_
			printf ("Could not listen on interface/port\n");
#else
			MessageBox (NULL, "Could not listen on interface/port", "Antinat",
						16);
#endif
			exit (EXIT_FAILURE);
		}
	}
#ifndef _WIN32_
//	signal (x, reloadconfig);
#endif
}

#ifndef _WIN32_
void
kidkiller (int x)
{
	int ret;
#ifdef WITH_DEBUG
	DEBUG_LOG ("It was dead already, honest...");
#endif
	wait (&ret);
//	signal (x, kidkiller);
}
#endif

void
closeup (int x)
{
#ifdef WITH_DEBUG
	DEBUG_LOG ("Closing up");
#endif
    an_active = NO;
	log_log (NULL, LOG_EVT_SERVERCLOSE, 0, conf);
	config_dereference (conf);
	/* FIXME: really want to wait for threads to finish properly */
//	sleep (1);					/* Give logging threads a chance */
}

int
realapp ()
{
    an_active = YES;
	while (an_active) {
		if (!HandleRequest ()) {
#ifdef WITH_DEBUG
			DEBUG_LOG ("Couldn't handle request.");
#endif
		}
	}
	return EXIT_SUCCESS;
}

int
an_setup (const char *an_config_content, int an_config_content_size)
{
    config_content = an_config_content;
    config_content_size = an_config_content_size;
    os_mutex_init (&crypt_lock);
    os_mutex_init (&getpwnam_lock);
    os_mutex_init (&getspnam_lock);
    os_mutex_init (&localtime_lock);
    os_mutex_init (&writerpipe_lock);
    reloadconfig (SIGHUP);
    config_content = NULL;
    config_content_size = 0;
    return srv;
}

int an_main() {
    return realapp ();
}

