/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#include <time.h>
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_IO_H
#include <io.h>
#endif
#ifdef HAVE_NETDB_H
#include <netdb.h>
#endif
#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif
//#include <Foundation/Foundation.h>

#include "antinat.h"

#ifndef _WIN32_
//int writerPipe = -1;
#endif

int
write_pipe_for_conn(conn_t *conn);

void
set_write_pip_for_conn(conn_t *conn, int write_pipe);

void
conn_init_tcp (conn_t * conn, config_t * theconf, SOCKET thiss)
{
	PI_SA sa;
	sl_t sl;
	conn->s = thiss;
	conn->conf = theconf;
	conn->user = NULL;
	conn->pass = NULL;

	conn->buffer = NULL;
	conn->bufflen = 0;

	conn->version = 0;
	conn->authscheme = 0;
	conn->authsrc = 0;

	ai_init (&conn->source, NULL);
	ai_init (&conn->dest, NULL);
	ai_init (&conn->source_on_server, NULL);

	sl = sizeof (sa);
	if (getpeername (conn->s, (SOCKADDR *) & sa, &sl) == 0) {
		ai_setAddress_sa (&conn->source, (SOCKADDR *) & sa);
	}
	if (getsockname (conn->s, (SOCKADDR *) & sa, &sl) == 0) {
		ai_setAddress_sa (&conn->source_on_server, (SOCKADDR *) & sa);
	}

	conn->nExternalSendBytes = 0;
	conn->nExternalRecvBytes = 0;
}

void
conn_init_udp (conn_t * conn, config_t * theconf, SOCKADDR * sa,
			   char *udppacket, int udplen)
{
	conn->s = 0;
	conn->user = NULL;
	conn->pass = NULL;
	conn->conf = theconf;

	conn->version = 0;
	conn->authscheme = 0;
	conn->authsrc = 0;

	ai_init (&conn->source, NULL);
	ai_init (&conn->dest, NULL);
	ai_init (&conn->source_on_server, NULL);

	conn->buffer = udppacket;
	conn->bufflen = udplen;
	conn->buff_upto = 0;

	ai_setAddress_sa (&conn->source, sa);

	conn->nExternalSendBytes = 0;
	conn->nExternalRecvBytes = 0;
}

void
conn_close (conn_t * conn)
{
	ai_close (&conn->source);
	ai_close (&conn->source_on_server);
	ai_close (&conn->dest);

	if (conn->user)
		free (conn->user);
	if (conn->pass)
		free (conn->pass);

	conn->user = conn->pass = NULL;

	free (conn);
}

void
conn_setUser (conn_t * conn, char *newuser)
{
	if (conn->user)
		free (conn->user);
	if (newuser == NULL) {
		conn->user = NULL;
	} else {
		conn->user = (char *) malloc (strlen (newuser) + 1);
		strcpy (conn->user, newuser);
	}
}

void
conn_setPass (conn_t * conn, char *newpass)
{
	if (conn->pass)
		free (conn->pass);
	if (newpass == NULL) {
		conn->pass = NULL;
	} else {
		conn->pass = (char *) malloc (strlen (newpass) + 1);
		strcpy (conn->pass, newpass);
	}
}

BOOL
conn_setDestHostname (conn_t * conn, char *host)
{
	HOSTENT *phe;
	HOSTENT realhe;
	char buf[1024];
	int perrno = 0;
	an_gethostbyname (host, &realhe, buf, sizeof (buf), &phe, &perrno);
	if (!phe) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Failed to resolve hostname");
#endif
		return FALSE;
	}
	conn->dest.address_type = phe->h_addrtype;
	ai_setAddress_str (&conn->dest, phe->h_addr_list[0], phe->h_length);
	return TRUE;
}

BOOL
conn_sendData (conn_t * conn, const char *szData, int nSize)
{
	if (conn->buffer) {
		int wanttosend;
		wanttosend = nSize;
		if (conn->buff_upto + wanttosend >= conn->bufflen) {
			wanttosend = conn->bufflen - conn->buff_upto;
		}
		memcpy (&conn->buffer[conn->buff_upto], szData, wanttosend);
		conn->buff_upto += wanttosend;
		if (nSize == wanttosend)
			return TRUE;
		return FALSE;
	} else {
		long ret;
		if (nSize < 0) {
			nSize = strlen (szData);
		}
		ret = send (conn->s, szData, nSize, 0);
		if (ret == nSize)
			return TRUE;
		return FALSE;
	}
}

static BOOLX
conn_waitForDataEx (SOCKET s, int sec, int usec)
{
	int ret;
	fd_set readset;
	struct timeval timeout;

	FD_ZERO (&readset);
	FD_SET (s, &readset);
	if (sec >= 0) {
		timeout.tv_sec = sec;
		timeout.tv_usec = usec;
		ret = select (s + 1, &readset, NULL, NULL, &timeout);
	} else {
		ret = select (s + 1, &readset, NULL, NULL, NULL);
	}
	if (ret > 0)
		return B_YES;
	if (ret == 0)
		return NOTYET;
#ifndef _WIN32_
	if (errno == EINTR)
		return NOTYET;
#endif
	return B_NO;
}

BOOL
conn_getChar (conn_t * conn, unsigned char *ch)
{
	if (conn->buffer) {
		/* UDP */
		if (conn->buff_upto < conn->bufflen) {
			*ch = conn->buffer[conn->buff_upto];
			conn->buff_upto++;
			return TRUE;
		}
		return FALSE;
	} else {
		/* TCP */
		int len;
		if (conn_waitForDataEx (conn->s, 60 * 5, 0) != YES)
			return FALSE;
		len = recv (conn->s, (char *) ch, 1, 0);
		if (len > 0)
			return TRUE;
		return FALSE;
	}
}

BOOL
conn_getSlab (conn_t * conn, char *szBuffer, int nSize)
{
	if (conn->buffer) {
		/* UDP */
		int wanttoread;
		wanttoread = nSize;
		if ((conn->buff_upto + wanttoread) >= conn->bufflen) {
			wanttoread = conn->bufflen - conn->buff_upto;
		}
		memcpy (szBuffer, &conn->buffer[conn->buff_upto], wanttoread);
		conn->buff_upto += wanttoread;
		if (nSize == wanttoread)
			return TRUE;
		return FALSE;
	} else {
		int len;
		if (nSize <= 0)
			return FALSE;

		do {
			if (conn_waitForDataEx (conn->s, 60 * 5, 0) != YES)
				return FALSE;
			len = recv (conn->s, szBuffer, nSize, 0);
			szBuffer[len] = '\0';
			szBuffer += len;
			nSize -= len;
		} while ((nSize > 0) && (len > 0));

		if (nSize == 0)
			return TRUE;
		return FALSE;
	}
}


typedef struct st_newConnInfo {
	conn_t *local;
	ANCONN remote;
	struct st_newConnInfo *next;
} newConnInfo;

typedef struct st_forwarderData {
#ifndef _WIN32_
	int readerPipe;
	int writerPipe;
#endif
	newConnInfo *init;
} forwarderData;

#ifndef _WIN32_
void *conn_forwarderThread (void *);

static BOOL
conn_createForwarderThread (conn_t * conn, ANCONN two)
{
	newConnInfo *ci;
	forwarderData *fd;
	int piperes[2];
	os_thread_t thr;

	if (os_pipe (piperes) != 0) {
		return FALSE;
	}

	fd = malloc (sizeof (forwarderData));
	if (!fd) {
		close (piperes[0]);
		close (piperes[1]);
		free (fd);
		return FALSE;
	}
	ci = malloc (sizeof (newConnInfo));
	if (!ci) {
		close (piperes[0]);
		close (piperes[1]);
		free (fd);
		free (ci);
		return FALSE;
	}
#ifdef WITH_DEBUG
    char s[100];
    sprintf(s, "socks server conn_createForwarderThread: read: %d, write: %d", piperes[0], piperes[1]);
    DEBUG_LOG(s);
#endif
	ci->local = conn;
	ci->remote = two;
	ci->next = NULL;
	fd->init = ci;
	fd->readerPipe = piperes[0];
	fd->writerPipe = piperes[1];
	/* Should be already locked */
    set_write_pip_for_conn(conn, fd->writerPipe);
#ifdef WITH_DEBUG
	DEBUG_LOG ("Attempting to create new thread");
#endif
	os_thread_init (&thr);
	if (os_thread_exec (&thr, conn_forwarderThread, fd)) {
		os_thread_detach (&thr);
		return TRUE;
	}

	close (piperes[0]);
	close (piperes[1]);
	free (fd);
	free (ci);
	return FALSE;
}
#endif

void *
conn_forwarderThread (void *data)
{
	forwarderData *mydata;
	newConnInfo *head;
	newConnInfo *current;
	newConnInfo *prev;
	int nConns;
	int maxConns;

	SOCKET biggest;
	fd_set fds;
	fd_set wait_q;
	int nActive;
	BOOL bCloseConn;
	BOOL bHaveThrottle;
	char szBuffer[32768];
	int len;
	int readlen;
	int currentrate;
	time_t now;
	struct timeval tv;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

#ifdef WITH_DEBUG
	DEBUG_LOG ("Created new forwarder thread");
#endif

	mydata = (forwarderData *) data;
	nConns = 1;
#ifndef _WIN32_
	maxConns = config_getMaxConnsPerThread (mydata->init->local->conf);
#else
	maxConns = 1;
#endif

	currentrate = 0;			/* Compiler shutup */
	bHaveThrottle = FALSE;

	head = mydata->init;
	head->next = NULL;
	FD_ZERO (&wait_q);

	while (1) {
		FD_ZERO (&fds);
#ifndef _WIN32_
		biggest = mydata->readerPipe;
		FD_SET (mydata->readerPipe, &fds);
#else
		biggest = 0;
#endif
		for (current = head; current; current = current->next) {
			/* If it's on the wait queue, don't select on it, because
			 * we know there's something to be read already, and didn't
			 * want to read it due to a throttle. */
			if (!FD_ISSET (current->local->s, &wait_q)) {
				if (current->local->s > biggest)
					biggest = current->local->s;
				FD_SET (current->local->s, &fds);
				biggest = AN_FD_SET (current->remote, &fds, biggest);
			}
		}
		biggest++;
		/* Wait for message from either side of any connection plus our
		 * special signalling pipe (non-Win32 only).  Have a timeout to
		 * handle throttled connections; we don't check if there's something
		 * to be read on those, but we do check every second whether we
		 * should start handling them again. */
		if (bHaveThrottle) {
			tv.tv_sec = 1;
			tv.tv_usec = 0;
			nActive = select (biggest, &fds, NULL, NULL, &tv);
		} else {
			/* No throttle, hang indefinitely. */
			nActive = select (biggest, &fds, NULL, NULL, NULL);
		}
		time (&now);
		FD_ZERO (&wait_q);
		bHaveThrottle = 0;

#ifndef _WIN32_
		if (FD_ISSET (mydata->readerPipe, &fds)) {
#ifdef WITH_DEBUG
			DEBUG_LOG ("Activity on new connection monitor");
#endif
			len = read (mydata->readerPipe, szBuffer, sizeof (newConnInfo));
			/* What if it comes in bits?  Need to handle this - FIXME */
#ifdef WITH_DEBUG
			sprintf (szDebug, " Got %i bytes, wanted %i bytes", len,
					 (int) sizeof (newConnInfo));
			DEBUG_LOG (szDebug);
#endif
			if (len == sizeof (newConnInfo)) {
				current = malloc (sizeof (newConnInfo));
				memcpy (current, szBuffer, sizeof (newConnInfo));
				if (nConns >= maxConns) {
					os_mutex_lock (&writerpipe_lock);
					conn_createForwarderThread (current->local,
												current->remote);
					os_mutex_unlock (&writerpipe_lock);
				} else {
					current->next = head;
					head = current;
					nConns++;
#ifdef WITH_DEBUG
					DEBUG_LOG ("Added new connection to forwarder thread");
#endif
				}
			}
		}
#endif

		prev = NULL;
		for (current = head; current;) {
			bCloseConn = FALSE;
			/* Is it throttled? */
			if (current->local->throttle) {
				if (now == current->local->startTime) {
					currentrate = (current->local->nExternalSendBytes +
								   current->local->nExternalRecvBytes);
				} else {
					currentrate = (current->local->nExternalSendBytes +
								   current->local->nExternalRecvBytes) /
						(now - current->local->startTime);
#ifdef WITH_DEBUG
					sprintf(szDebug, "currentrate is now %i",currentrate);
					DEBUG_LOG(szDebug);
#endif
				}
			}
			if (current->local->throttle
				&& currentrate >= current->local->throttle) {
				/* Only need one because all we're checking for above is that
				 * particular connection; we assume both shouldn't be added
				 * to select anyway */
				FD_SET (current->local->s, &wait_q);
				bHaveThrottle = TRUE;
			} else {
				readlen = sizeof (szBuffer) - 1;
				if (current->local->throttle)
					if (current->local->throttle < readlen)
						readlen = current->local->throttle;
				if (FD_ISSET (current->local->s, &fds)) {
					/* A message from the LAN, forward to the server */
					len = recv (current->local->s, szBuffer, readlen, 0);
					if (len <= 0) {
#ifdef WITH_DEBUG
						DEBUG_LOG ("Connection closed by local");
#endif
						/* Connection closed */
						bCloseConn = TRUE;
					} else {
						current->local->nExternalSendBytes += len;
						szBuffer[len] = '\0';
#ifdef WITH_DEBUG
                        sprintf (szDebug, "Send %i bytes local->remote", len);
                        DEBUG_LOG (szDebug);
#endif
						an_send (current->remote, szBuffer, len, 0);
					}
				}
				if (AN_FD_ISSET (current->remote, &fds)) {
					/* A message from the server, forward to the LAN */
					len = an_recv (current->remote, szBuffer, readlen, 0);
					if (len <= 0) {
#ifdef WITH_DEBUG
						DEBUG_LOG ("Connection closed by remote");
#endif
						/* Connection closed */
						bCloseConn = TRUE;
					} else {
						current->local->nExternalRecvBytes += len;
						szBuffer[len] = '\0';
						send (current->local->s, szBuffer, len, 0);
#ifdef WITH_DEBUG
						sprintf (szDebug, "Send %i bytes remote->local", len);
						DEBUG_LOG (szDebug);
#endif
					}
				}
				if (bCloseConn) {
					an_close (current->remote);
					an_destroy (current->remote);
					closesocket (current->local->s);
					log_log (current->local, LOG_EVT_LOG,
							 LOG_TYPE_CONNECTIONCLOSE, NULL);
#ifdef WITH_DEBUG
					DEBUG_LOG ("Cleaning up from connection");
#endif
					config_dereference (current->local->conf);
					conn_close (current->local);
					if (prev) {
						prev->next = current->next;
					} else {
						head = current->next;
					}
#ifndef _WIN32_
					free (current);
					current = prev;
					nConns--;
					if (nConns == 0) {
						os_mutex_lock (&writerpipe_lock);
//                        int write_pipe = write_pipe_for_conn(mydata->init->local);
//						if (mydata->writerPipe != write_pipe) {
							/* No connections, and we're not the active
							 * thread anymore.  This is where we croak.
							 */
							os_mutex_unlock (&writerpipe_lock);
							close (mydata->writerPipe);
							close (mydata->readerPipe);
							free (mydata);
#endif
#ifdef WITH_DEBUG
							DEBUG_LOG ("Cleaned up old forwarder thread");
#endif
							return NULL;
#ifndef _WIN32_
//						}
//						os_mutex_unlock (&writerpipe_lock);
					}
#endif
				}
			}
			if (!bCloseConn)
				prev = current;
			if (current)
				current = current->next;

		}
	}

	return NULL;
}

BOOL
conn_forwardData (conn_t * conn, ANCONN two)
{
#ifdef _WIN32_
	newConnInfo ci;
	forwarderData fd;
#endif
	time_t now;
#ifdef WITH_DEBUG
	char szDebug[100];

	sprintf (szDebug, "Forwarding connection with throttle of %i",
			 conn->throttle);
	DEBUG_LOG (szDebug);
#endif
	time (&now);
	conn->startTime = now;
#ifdef _WIN32_
	ci.local = conn;
	ci.remote = two;
	ci.next = NULL;
	fd.init = &ci;
	conn_forwarderThread (&fd);
	return TRUE;
#else
#ifdef WITH_DEBUG
    char s[100];
    sprintf(s, "Attempting to forward data for connection: local: <%s:%d>, dest: <%s:%d>", conn->source.address, conn->source.port, conn->dest.address, conn->dest.port );
	DEBUG_LOG (s);
#endif

	os_mutex_lock (&writerpipe_lock);
    int write_pipe = write_pipe_for_conn(conn);
	if (write_pipe == -1) {
#ifdef WITH_DEBUG
        DEBUG_LOG("Create forwarder thread");
#endif
		conn_createForwarderThread (conn, two);
	} else {
#ifdef WITH_DEBUG
        char s[100];
        sprintf(s, "Write to exist pipe: %d", write_pipe);
        DEBUG_LOG(s);
#endif
		newConnInfo ci;
		ci.local = conn;
		ci.remote = two;
		ci.next = NULL;
		if (write (write_pipe, &ci, sizeof (ci)) < 0) {
			os_mutex_unlock (&writerpipe_lock);
			return FALSE;
		}
	}
	os_mutex_unlock (&writerpipe_lock);
	return TRUE;
#endif
}

int
write_pipe_for_conn(conn_t *conn) {
    char *s = ai_getString(&conn->source);
    char *d = ai_getString(&conn->source);
    NSString *key = [NSString stringWithFormat:@"%s-%s", s, d];
    free(s);
    free(d);
    if (conn_dict[key]) {
        return [conn_dict[key] intValue];
    }
    return -1;
}

void set_write_pip_for_conn(conn_t *conn, int write_pipe) {
    char *s = ai_getString(&conn->source);
    char *d = ai_getString(&conn->source);
    NSString *key = [NSString stringWithFormat:@"%s-%s", s, d];
    free(s);
    free(d);
    conn_dict[key] = @(write_pipe);
}

BOOL
conn_setupchain (conn_t * conn, ANCONN remote, chain_t * chain)
{
	char *upstreamuser;
	char *upstreampass;
	int i;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	if (chain) {
		an_set_proxy_url (remote, chain->uri);
		for (i = 1; i < 32; i++) {
			if (chain->authschemes & (1 << i))
				an_set_authscheme (remote, i);
		}
		if (chain->user)
			upstreamuser = chain->user;
		else
			upstreamuser = conn->user;

		if (chain->pass)
			upstreampass = chain->pass;
		else
			upstreampass = conn->pass;
		an_set_credentials (remote, upstreamuser, upstreampass);
#ifdef WITH_DEBUG
		sprintf (szDebug, "Chaining to %s as %s,%p", chain->uri, upstreamuser,
				 upstreampass);
		DEBUG_LOG (szDebug);
#endif
	} else {
		/* Death to environment variables */
		an_unset_proxy (remote);
	}
	return TRUE;
}

void *
ChildThread (void *conn)
{
	conn_t *connection;
	unsigned char ver;
	BOOL ret;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	connection = (conn_t *) conn;

	ret = FALSE;

	if (!conn_getChar (connection, &ver))
		goto barfed;
#ifdef WITH_DEBUG
	sprintf (szDebug, "Version: %x", ver);
	DEBUG_LOG (szDebug);
#endif
	connection->version = ver;
	switch (ver) {
	case 4:
		ret = socks4_handler (connection);
		break;
	case 5:
		ret = socks5_handler (connection);
		break;
	}
  barfed:
	if (ret == FALSE) {
		closesocket (connection->s);
		log_log (connection, LOG_EVT_LOG, LOG_TYPE_CONNECTIONCLOSE, NULL);
#ifdef WITH_DEBUG
		DEBUG_LOG ("Cleaning up from unsuccessful connection");
#endif
		config_dereference (connection->conf);
		conn_close (connection);
	}
	return NULL;
}
