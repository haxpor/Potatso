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
#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif
#ifdef HAVE_NETINET_IN6_H
#include <netinet/in6.h>
#endif
#ifdef HAVE_NETINET6_IN_H
#include <netinet6/in.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_CTYPE_H
#include <ctype.h>
#endif
#ifdef HAVE_LIMITS_H
#include <limits.h>
#endif
#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

static BOOL
socks5_resolve_ipv4 (conn_t * conn)
{
	unsigned short port;
	char temp[5];
	conn->dest.address_type = AF_INET;
	conn_getSlab (conn, temp, 4);
	ai_setAddress_str (&conn->dest, (char *) &temp, 4);
	conn_getSlab (conn, temp, 2);
	memcpy (&port, temp, 2);
	conn->dest.port = port;
	return TRUE;
}

#ifdef WITH_IPV6
static BOOL
socks5_resolve_ipv6 (conn_t * conn)
{
	unsigned short port;
	char temp[17];
	conn->dest.address_type = AF_INET6;
	conn_getSlab (conn, temp, 16);
	ai_setAddress_str (&conn->dest, (char *) &temp, 16);
	conn_getSlab (conn, temp, 2);
	memcpy (&port, temp, 2);
	conn->dest.port = port;
	return TRUE;
}
#endif

static BOOL
socks5_resolve_name (conn_t * conn)
{
	unsigned char len;

	char temp[257];
	char tmpPort[3];
	unsigned short port;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

	conn_getChar (conn, &len);

	/* getSlab null terminates */
	conn_getSlab (conn, temp, len);
#ifdef WITH_DEBUG
	sprintf (szDebug, "name trying to connect to %s", temp);
	DEBUG_LOG (szDebug);
#endif
	conn_getSlab (conn, tmpPort, 2);
	memcpy (&port, tmpPort, 2);
	conn->dest.port = port;
	return conn_setDestHostname (conn, temp);
}

static BOOL
socks5_revres_ipv4 (conn_t * conn, SOCKADDR * sa)
{
	char szTemp[2];
	SOCKADDR_IN *sin;
	if (sa->sa_family != AF_INET)
		return FALSE;
	sin = (SOCKADDR_IN *) sa;
	szTemp[0] = 0x01;
	conn_sendData (conn, szTemp, 1);
	conn_sendData (conn, (char *) &sin->sin_addr.s_addr, 4);
	conn_sendData (conn, (char *) &sin->sin_port, 2);
	return TRUE;
}

#ifdef WITH_IPV6
static BOOL
socks5_revres_ipv6 (conn_t * conn, SOCKADDR * sa)
{
	char szTemp[2];
	SOCKADDR_IN6 *sin;
	if (sa->sa_family != AF_INET6)
		return FALSE;
	sin = (SOCKADDR_IN6 *) sa;
	szTemp[0] = 0x04;

	conn_sendData (conn, szTemp, 1);
	conn_sendData (conn, (char *) sin->sin6_addr.s6_addr, 16);
	conn_sendData (conn, (char *) &sin->sin6_port, 2);
	return TRUE;
}
#endif

static BOOL
socks5_revresolve (conn_t * conn, SOCKADDR * sa, BOOL bReportFail)
{
	BOOL familyunrecognised = FALSE;
	unsigned char szTemp[16];
	if (sa)
		switch (sa->sa_family) {
		case AF_INET:
			return socks5_revres_ipv4 (conn, sa);
			break;
#ifdef WITH_IPV6
		case AF_INET6:
			return socks5_revres_ipv6 (conn, sa);
			break;
#endif
		default:
			familyunrecognised = TRUE;
			break;

		}

	if (bReportFail) {
		int i;
		szTemp[0] = 0x01;
		for (i = 1; i < 7; i++)
			szTemp[i] = 0x00;
		conn_sendData (conn, (const char *) szTemp, 7);
		return TRUE;
	}
	return FALSE;
}

static BOOL
socks5_sendResponse (conn_t * conn, char rep, SOCKADDR * sa)
{
	char szResp[100];
	char szTemp[10];
	char *oldbuffer;
	int oldbuflen;
	int oldbuff_upto;
	int havetosend;

	/* Take a copy of the old buffer info */
	oldbuffer = conn->buffer;
	oldbuflen = conn->bufflen;
	oldbuff_upto = conn->buff_upto;

	/* Set up writes to temp location */
	conn->buffer = szResp;
	conn->bufflen = sizeof (szResp);
	conn->buff_upto = 0;

	szTemp[0] = 0x05;
	szTemp[1] = rep;
	szTemp[2] = 0x00;
	conn_sendData (conn, szTemp, 3);
	socks5_revresolve (conn, sa, TRUE);

	havetosend = conn->buff_upto;

	/* Write to wherever the old buffer was, hopefully network */
	conn->buffer = oldbuffer;
	conn->bufflen = oldbuflen;
	conn->buff_upto = oldbuff_upto;

	conn_sendData (conn, szResp, havetosend);
	return TRUE;
}

static BOOL
socks5_resolve (conn_t * conn, unsigned char atyp, BOOL bReportFail)
{
#ifdef WITH_DEBUG
	char szDebug[100];
#endif
	switch (atyp) {
	case 0x01:					/* IPv4 */
		return socks5_resolve_ipv4 (conn);
		break;
	case 0x03:					/* Hostname */
		return socks5_resolve_name (conn);
		break;
#ifdef WITH_IPV6
	case 0x04:					/* IPv6 */
		return socks5_resolve_ipv6 (conn);
		break;
#endif
	default:
#ifdef WITH_DEBUG
		sprintf (szDebug, "No resolver %x", atyp);
		DEBUG_LOG (szDebug);
#endif
		if (bReportFail)
			socks5_sendResponse (conn, 0x08, NULL);
		return FALSE;
		break;
	}
}


static BOOL
socks5_forwardUDPData (conn_t * tcpconn, SOCKET one, SOCKET two)
{
	char *tmpbuf;
	int tmplen;
	sl_t addrlen;
	BOOL finished;
	char szBuffer[8192];
	SOCKET biggest;
	int len;
	int diff;
	fd_set fds;
	PI_SA sa_local;
	PI_SA sa_remote;
	sl_t localsize;
	sl_t sl;
	/* Where did the most recent LAN packet come from? */
	SOCKADDR *remoteaddr;
	SOCKADDR *localaddr;
	SOCKET tcpsock;
	char *addrstring1;
	char *addrstring2;
	chain_t *chain;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

	tcpsock = tcpconn->s;

#ifdef WITH_DEBUG
	DEBUG_LOG ("Entering UDP forward");
#endif

	finished = FALSE;
	remoteaddr = NULL;
	localaddr = NULL;
	localsize = 0;
	while (!finished) {
	  barfedinbound:
		FD_ZERO (&fds);
		FD_SET (tcpsock, &fds);
		FD_SET (one, &fds);
		FD_SET (two, &fds);
		biggest = tcpsock;
		if (one > biggest)
			biggest = one;
		if (two > biggest)
			biggest = two;
		biggest++;
		/* Wait for message from either side */
		select (biggest, &fds, NULL, NULL, NULL);
		if (FD_ISSET (tcpsock, &fds)) {
			/* We got something on TCP.  I read somewhere that
			 * some vendors have been extending the spec here.
			 * But it's not standard, and I'm ignoring it.  As
			 * soon as a read fails here, then the association is
			 * over.
			 */
			len = recv (tcpsock, szBuffer, sizeof (szBuffer) - 1, 0);
			if (len <= 0) {
				finished = TRUE;
#ifdef WITH_DEBUG
				DEBUG_LOG ("TCP close");
#endif
			} else {
#ifdef WITH_DEBUG
				DEBUG_LOG ("TCP activity");
#endif
			}
		}
		if (FD_ISSET (one, &fds)) {
			sl = sizeof (sa_local);
#ifdef WITH_DEBUG
			DEBUG_LOG ("Outbound UDP packet");
#endif
			/* FIXME: Overwrites local with each incoming packet */
			len = recvfrom (one, szBuffer,
							sizeof (szBuffer) - 1, 0, (SOCKADDR *) & sa_local,
							&sl);
			if (len > 0) {

				unsigned char ch;
				conn_t udpconn;
				if (!localaddr) {
					localaddr = (SOCKADDR *) & sa_local;
					localsize = sl;
				}
				szBuffer[len] = '\0';
				conn_init_udp (&udpconn, tcpconn->conf,
							   (SOCKADDR *) & sa_local, szBuffer, len);

				/* Check that packet came from same place as
				 * TCP connection */
				addrstring1 = ai_getAddressString (&tcpconn->source);
				addrstring2 = ai_getAddressString (&udpconn.source);
				diff = strcmp (addrstring1, addrstring2);
#ifdef WITH_DEBUG
				if (diff) {
					sprintf
						(szDebug,
						 "TCP source (%s) != UDP source (%s), dropping packet",
						 addrstring1, addrstring2);
					DEBUG_LOG (szDebug);
				}
#endif
				free (addrstring1);
				free (addrstring2);
				if (diff)
					goto barfedoutbound;

				conn_setUser (&udpconn, tcpconn->user);
				conn_setPass (&udpconn, tcpconn->pass);

				/* Reserved */
				if (!conn_getChar (&udpconn, &ch))
					goto barfedoutbound;
				if (ch != '\0')
					goto barfedoutbound;

				/* Reserved */
				if (!conn_getChar (&udpconn, &ch))
					goto barfedoutbound;
				if (ch != '\0')
					goto barfedoutbound;

				/* Fragmentation (not handled yet) */
				if (!conn_getChar (&udpconn, &ch))
					goto barfedoutbound;
				if (ch != '\0')
					goto barfedoutbound;

				/* Address type */
				if (!conn_getChar (&udpconn, &ch))
					goto barfedoutbound;
				if (!socks5_resolve ((conn_t *) & udpconn, ch, FALSE))
					goto barfedoutbound;

				if (!tcpconn->dest.nulladdr) {
					addrstring1 = ai_getAddressString (&tcpconn->dest);
					addrstring2 = ai_getAddressString (&udpconn.dest);
					diff = strcmp (addrstring1, addrstring2);
					free (addrstring1);
					free (addrstring2);
#ifdef WITH_DEBUG
					if (diff)
						DEBUG_LOG ("TCP dest != UDP dest");
#endif
					if (diff)
						goto barfedoutbound;
				}

				/* We don't know how to chain UDP yet. */
				if (!config_isallowed (udpconn.conf, &udpconn, &chain)) {
					goto barfedoutbound;
				}
				if (remoteaddr)
					free (remoteaddr);
				ai_getSockaddr (&udpconn.dest, &remoteaddr, &addrlen);
				tmpbuf = udpconn.buffer + udpconn.buff_upto;
				tmplen = udpconn.bufflen - udpconn.buff_upto;
				/* FIXME: FILTERING!! */
				sendto (two, tmpbuf, tmplen, 0, remoteaddr, addrlen);
#ifdef WITH_DEBUG
				sprintf (szDebug, "Send %i bytes local->remote", len);
				DEBUG_LOG (szDebug);
#endif
			}
		}
	  barfedoutbound:
		if (FD_ISSET (two, &fds)) {
#ifdef WITH_DEBUG
			DEBUG_LOG ("inbound UDP packet");
#endif
			/* A message from the world, forward to the LAN */
			sl = sizeof (sa_remote);
			len = recvfrom (two, szBuffer,
							sizeof (szBuffer) - 1, 0,
							(SOCKADDR *) & sa_remote, &sl);
			if (len > 0) {
				char szBufferTwo[8300];
				char szTemp[16];
				conn_t udpconn;
				if (!remoteaddr)
					goto barfedinbound;
				if (!localaddr)
					goto barfedinbound;
				/* Note: in this case, the source address is
				 * the recipient...*/
				conn_init_udp (&udpconn, tcpconn->conf,
							   (SOCKADDR *) & sa_remote,
							   szBufferTwo, sizeof (szBufferTwo));
				if (!tcpconn->dest.nulladdr) {
					addrstring1 = ai_getAddressString (&tcpconn->dest);
					addrstring2 = ai_getAddressString (&udpconn.source);
					diff = strcmp (addrstring1, addrstring2);
					free (addrstring1);
					free (addrstring2);
					if (diff)
						goto barfedinbound;
				}
				szTemp[0] = '\0';	/* Res */
				szTemp[1] = '\0';	/* Res */
				szTemp[2] = '\0';	/* Fragmentation */
				conn_sendData (&udpconn, szTemp, 3);

				if (!socks5_revresolve (&udpconn, localaddr, FALSE))
					goto barfedinbound;
				conn_sendData (&udpconn, szBuffer, len);
				tmpbuf = udpconn.buffer;
				tmplen = udpconn.bufflen;
				/* I'm assuming that there's no point filtering
				 * incoming UDP packets; if an outgoing packet
				 * is allowed to reach the destination, the
				 * destination should be allowed to reach the
				 * source.*/
				sendto (one, tmpbuf, tmplen, 0, localaddr, localsize);
#ifdef WITH_DEBUG
				sprintf (szDebug, "Send %i bytes remote->local", len);
				DEBUG_LOG (szDebug);
#endif
			}
		}
	}
	if (remoteaddr)
		free (remoteaddr);
	return TRUE;
}

static BOOL
socks5_cmd_udp (conn_t * conn)
{
	SOCKET remotelisten, remotetalk;
	PI_SA sout;
	sl_t soutlen;
	SOCKADDR *addr;
	sl_t addrlen;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif

	if (!ai_getSockaddr (&conn->dest, &addr, &addrlen))
		return FALSE;
#ifdef WITH_DEBUG
	sprintf (szDebug, "Socket family: %x", addr->sa_family);
	DEBUG_LOG (szDebug);
#endif
	remotelisten = socket (addr->sa_family, SOCK_DGRAM, IPPROTO_UDP);
#ifdef WITH_DEBUG
	{
		char *dest;
		dest = ai_getString (&conn->dest);
		sprintf (szDebug, "Binding to %s", dest);
		DEBUG_LOG (szDebug);
		free (dest);
	}
#endif
	/* FIXME: This hack listens on all interfaces on any port.
	 * Is this really what the spec had in mind? */
	memset (&sout, 0, sizeof (sout));
	((SOCKADDR *) & sout)->sa_family = addr->sa_family;
	soutlen = addrlen;
	if (bind (remotelisten, (SOCKADDR *) & sout, soutlen) != 0) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind failed");
#endif
		closesocket (remotelisten);
		socks5_sendResponse (conn, 0x01, NULL);
		free (addr);
		return FALSE;
	}
	remotetalk = socket (addr->sa_family, SOCK_DGRAM, IPPROTO_UDP);
	soutlen = sizeof (sout);
	if (getsockname (remotelisten, (SOCKADDR *) & sout, &soutlen) != 0) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("getsockname failed");
#endif
	}
	socks5_sendResponse (conn, 0x00, (SOCKADDR *) & sout);

	memset (&sout, 0, sizeof (sout));
	((SOCKADDR *) & sout)->sa_family = addr->sa_family;
	soutlen = addrlen;
	bind (remotetalk, (SOCKADDR *) & sout, soutlen);

	socks5_forwardUDPData (conn, remotelisten, remotetalk);
	closesocket (remotetalk);
	closesocket (remotelisten);
    free (addr);
	return TRUE;
}

static BOOL
socks5_cmd_ident (conn_t * conn)
{
	char szTemp[64];
	sprintf (szTemp, "Antinat version %s\n", AN_VER);
	conn_sendData (conn, szTemp, -1);
	return TRUE;
}

/* This function reports to the client a socket's specs. */
static void
socks5_notifyclient (conn_t * conn, ANCONN s, SOCKADDR * sout, sl_t soutlen)
{
	if (an_getsockname (s, sout, soutlen) == AN_ERROR_SUCCESS) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind succeeded, interface known");
#endif
		socks5_sendResponse (conn, 0x00, sout);
	} else {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind succeeded, interface unknown");
#endif
		socks5_sendResponse (conn, 0x00, NULL);
	}
}

static BOOL
socks5_cmd_bind (conn_t * conn, chain_t * chain)
{
	ANCONN remote;
	SOCKET top;
	PI_SA sout;
	PI_SA locallistener;
	sl_t soutlen;
	SOCKADDR *addr;
	sl_t addrlen;
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
		char *dest;
		dest = ai_getString (&conn->dest);
		sprintf (szDebug, "Binding to %s", dest);
		DEBUG_LOG (szDebug);
		free (dest);
	}
#endif
	/* FIXME: This hack listens on all interfaces on any port.
	 * Is this really what the spec had in mind? */
	if ((remote == NULL) ||
		(an_bind_tosockaddr (remote, (SOCKADDR *) addr, addrlen) !=
		 AN_ERROR_SUCCESS) || (an_listen (remote) != AN_ERROR_SUCCESS)) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Bind failed");
#endif
		an_close (remote);
		an_destroy (remote);
		socks5_sendResponse (conn, 0x01, NULL);
		free (addr);
		return FALSE;
	}
	soutlen = sizeof (locallistener);
	socks5_notifyclient (conn, remote, (SOCKADDR *) & locallistener, soutlen);
	/* Wait to see if a connection is arriving in a reasonable time */

	top = conn->s;
	FD_ZERO (&fds);
	FD_SET (conn->s, &fds);
	top = AN_FD_SET (remote, &fds, top);
	tv.tv_sec = config_getMaxbindwait (conn->conf);
	tv.tv_usec = 0;
	select (top + 1, &fds, NULL, NULL, &tv);

	if (AN_FD_ISSET (remote, &fds)) {
		addrinfo_t ai;
		int correct;
		char *whoArrived;
		char *whoShould;
		/* Now to wait for incoming connection */
		memset (&sout, 0, sizeof (sout));
		((SOCKADDR *) & sout)->sa_family = addr->sa_family;
		free (addr);
		soutlen = sizeof (sout);
		if (an_accept (remote, (SOCKADDR *) & sout, soutlen) !=
			AN_ERROR_SUCCESS) {
			/* Whoa, accept() failed.  Better tell client */
			an_close (remote);
			an_destroy (remote);
#ifdef WITH_DEBUG
			DEBUG_LOG ("an_accept failed");
#endif
			socks5_sendResponse (conn, 0x01, NULL);
			return FALSE;
		}
		ai_init (&ai, ((SOCKADDR *) & sout));
		whoArrived = ai_getAddressString (&ai);
		whoShould = ai_getAddressString (&conn->dest);
		ai_close (&ai);
		correct = strcmp (whoArrived, whoShould);
		free (whoArrived);
		free (whoShould);
		if (correct != 0) {
			/* Somebody connected who shouldn't have. */
#ifdef WITH_DEBUG
			DEBUG_LOG ("Connection not from the right host");
#endif
			socks5_sendResponse (conn, 0x01, NULL);
			an_close (remote);
			an_destroy (remote);
			return FALSE;
		}

		/* Tell client who just arrived */
		socks5_notifyclient (conn, remote, (SOCKADDR *) & sout, soutlen);

		log_log (conn, LOG_EVT_LOG, LOG_TYPE_CONNECTIONESTABLISHED, NULL);

		/* As with connect, start forwarding data. */
		conn_forwardData (conn, remote);
	} else {
#ifdef WITH_DEBUG
		DEBUG_LOG ("select returned but without a connection");
#endif
		free (addr);
		/* Either outside connection timed out or inside
		 * tried something */
		socks5_sendResponse (conn, 0x01, NULL);
		an_close (remote);
		an_destroy (remote);
		return FALSE;
	}

	return TRUE;
}

static BOOL
socks5_cmd_conn (conn_t * conn, chain_t * chain)
{
	ANCONN remote;
	PI_SA sout;
	SOCKADDR *addr;
	sl_t addrlen;
	sl_t soutlen;
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
		char *dest;
		dest = ai_getString (&conn->dest);
		sprintf (szDebug, "Connecting to %s", dest);
		DEBUG_LOG (szDebug);
		free (dest);
	}
#endif

	if (an_connect_tosockaddr (remote, addr, addrlen) != AN_ERROR_SUCCESS) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Connection failed");
#endif
		an_close (remote);
		an_destroy (remote);
		socks5_sendResponse (conn, 0x05, NULL);
		free (addr);
		return FALSE;
	}
	free (addr);
	soutlen = sizeof (sout);
	if (an_getsockname (remote, (SOCKADDR *) & sout, soutlen) ==
		AN_ERROR_SUCCESS) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Connection succeeded, interface known");
#endif
		socks5_sendResponse (conn, 0x00, (SOCKADDR *) & sout);
	} else {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Connection succeeded, interface unknown");
#endif
		socks5_sendResponse (conn, 0x00, NULL);
	}
	log_log (conn, LOG_EVT_LOG, LOG_TYPE_CONNECTIONESTABLISHED, NULL);
	conn_forwardData (conn, remote);

	return TRUE;
}


static BOOL
socks5_initial (conn_t * conn)
{
	unsigned char nMethods;
	unsigned char chosenmethod;
	unsigned char szData[260];
#ifdef WITH_DEBUG
	char szDebug[100];
#endif

	if (!conn_getChar (conn, &nMethods))
		return FALSE;
#ifdef WITH_DEBUG
	sprintf (szDebug, "Number of Methods: %i", nMethods);
	DEBUG_LOG (szDebug);
#endif
	if (!conn_getSlab (conn, (char *) szData, nMethods))
		return FALSE;
	chosenmethod = config_choosemethod (conn->conf, conn, szData, nMethods);
#ifdef WITH_DEBUG
	sprintf (szDebug, "Chosen method %i", chosenmethod);
	DEBUG_LOG (szDebug);
#endif
	szData[0] = 0x05;
	szData[1] = chosenmethod;
	conn_sendData (conn, (char *) szData, 2);
	if (chosenmethod != 0xff) {
		conn->authscheme = chosenmethod;
		switch (chosenmethod) {
		case 0x00:
			return TRUE;
			break;
		case 0x02:
			return auth_unpw (conn);
			break;
		case 0x03:
			return auth_chap (conn);
			break;
		default:				/* wtf - don't allow methods without
								   implementing them */
			return FALSE;
		}
	} else
		return FALSE;
}

static BOOL
socks5_request (conn_t * conn)
{
	unsigned char version;
	unsigned char cmd;
	unsigned char res;
	unsigned char atyp;
	BOOL ret;
	chain_t *chain;
#ifdef WITH_DEBUG
	char szDebug[100];
#endif

	if (!conn_getChar (conn, &version))
		return FALSE;
	if (version != 5)
		return FALSE;
	if (!conn_getChar (conn, &cmd))
		return FALSE;
	if (!conn_getChar (conn, &res))
		return FALSE;
	if (!conn_getChar (conn, &atyp))
		return FALSE;
	if (!socks5_resolve (conn, atyp, TRUE))
		return FALSE;
	if (conn->dest.addrlen == 0) {
#ifdef WITH_DEBUG
		DEBUG_LOG ("Resolver failed");
#endif
		socks5_sendResponse (conn, 0x04, NULL);	/* Host unreachable */
		return FALSE;
	}
	conn->socksop = cmd;
	if (!config_isallowed (conn->conf, conn, &chain)) {
		return FALSE;
	}
	switch (cmd) {
	case 0x01:					/* Connect */
		ret = socks5_cmd_conn (conn, chain);
		break;
	case 0x02:					/* Bind */
		ret = socks5_cmd_bind (conn, chain);
		break;
	case 0x03:					/* UDP */
		ret = socks5_cmd_udp (conn);
		break;
	case 0x88:					/* Identify */
		ret = socks5_cmd_ident (conn);
		break;
	default:
#ifdef WITH_DEBUG
		sprintf (szDebug, "No command %x", cmd);
		DEBUG_LOG (szDebug);
#endif
		socks5_sendResponse (conn, 0x07, NULL);
		return FALSE;
		break;
	}
	return ret;
}

BOOL
socks5_handler (conn_t * conn)
{
	if (!socks5_initial ((conn_t *) conn))
		return FALSE;
#ifdef WITH_DEBUG
	DEBUG_LOG ("passed initialization");
#endif
	return socks5_request ((conn_t *) conn);
}
