/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_internals.h"

#include "antinat.h"
#include "an_core.h"

#include <stdio.h>

int
an_direct_close (ANCONN conn)
{
	return _an_generic_close (conn);
}

int
an_direct_connect_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	unsigned short oldblocking;
	int ret;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	conn->connection = socket (sa->sa_family, SOCK_STREAM, 0);
	if (conn->connection == AN_INVALID_CONNECTION) {
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_NETWORK;
	}

	ret = connect (conn->connection, sa, len);
	if (ret != 0) {
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_NETWORK;
	}

	_an_setsockaddr_sock (&conn->peer, conn->connection, 1);
	_an_setsockaddr_sock (&conn->local, conn->connection, 0);

	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_CONNECTED;

	return AN_ERROR_SUCCESS;
}

int
an_direct_connect_tohostname (ANCONN conn, const char *hostname,
							  unsigned short port)
{
	unsigned short oldblocking;
	int ret;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	if (conn->proxy_hostname != NULL)
		free (conn->proxy_hostname);
	conn->proxy_hostname = (char *) malloc (strlen (hostname) + 1);
	if (conn->proxy_hostname == NULL)
		return AN_ERROR_NOMEM;
	strcpy (conn->proxy_hostname, hostname);
	conn->proxy_port = port;
	conn->proxy_pf = AF_INET;

	ret = _an_rawconnect (conn);
	if (ret != AN_ERROR_SUCCESS) {
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	_an_setsockaddr_sock (&conn->peer, conn->connection, 1);
	_an_setsockaddr_sock (&conn->local, conn->connection, 0);
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_CONNECTED;
	return AN_ERROR_SUCCESS;
}

int
an_direct_recv (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	return _an_generic_recv (conn, buf, len, flags);
}

int
an_direct_send (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	return _an_generic_send (conn, buf, len, flags);
}

int
an_direct_bind_tohostname (ANCONN conn, const char *hostname,
						   unsigned short port)
{
	PI_SA sin;
	HOSTENT he;
	char buf2[1024];
	int perrno;
	PHOSTENT phe;

	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	an_gethostbyname (hostname, &he, buf2, sizeof (buf2), &phe, &perrno);
	if (phe == NULL)
		return AN_ERROR_NETWORK;

	memset (&sin, 0, sizeof (sin));
#ifdef WITH_IPV6
	sin.sin6_family = phe->h_addrtype;
	memcpy (&sin.sin6_addr.s6_addr, phe->h_addr, phe->h_length);
	sin.sin6_port = htons (port);
#else
	sin.sin_family = phe->h_addrtype;
	memcpy (&sin.sin_addr.s_addr, phe->h_addr, phe->h_length);
	sin.sin_port = htons (port);
#endif
	return an_direct_bind_tosockaddr (conn, (SOCKADDR *) & sin, sizeof (sin));
}

int
an_direct_bind_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	unsigned short oldblocking;
	int ret;
	PI_SA tmpdst;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;

	conn->connection = socket (sa->sa_family, SOCK_STREAM, 0);
	if (conn->connection < 0)
		return AN_ERROR_NETWORK;

	switch (sa->sa_family) {
#ifdef WITH_IPV6
	case AF_INET6:
		conn->peer.family = AF_INET6;
		memcpy (&conn->peer.address,
				&((SOCKADDR_IN6 *) sa)->sin6_addr.s6_addr, 16);
		conn->peer.port = ((SOCKADDR_IN6 *) sa)->sin6_port;
		break;
#endif
	case AF_INET:
		conn->peer.family = AF_INET;
		memcpy (&conn->peer.address, &((SOCKADDR_IN *) sa)->sin_addr.s_addr,
				4);
		conn->peer.port = ((SOCKADDR_IN *) sa)->sin_port;
		break;
	default:
		return AN_ERROR_NOTSUPPORTED;
	}

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	memset (&tmpdst, 0, sizeof(tmpdst));

#ifdef WITH_IPV6
	/* With IPv6, we should be able to support both - what we want is to bind
	 * to any protocol.  It looks like AF_INET does this.  But that might not
	 * be the case on all platforms... at the moment, this code pretty much
	 * requires you to use IPv6 if you compile with IPv6 support.  I'm not
	 * sure where to go with this - FIXME. */
	tmpdst.sin6_family = AF_INET6;
	tmpdst.sin6_addr = in6addr_any;
	tmpdst.sin6_port = 0;
#else
	tmpdst.sin_family = AF_INET;
	tmpdst.sin_addr.s_addr = INADDR_ANY;
	tmpdst.sin_port = 0;
#endif

	ret = bind (conn->connection, (SOCKADDR *) & tmpdst, sizeof (tmpdst));
	if (ret < 0) {
		perror ("bind");
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_NETWORK;
	}
	/* Another FIXME - it seems like this returns 0 on most platforms.  The
	 * OS won't assign a name to our socket until it knows where the
	 * incoming connection is coming from.  This gets very circular. */
	_an_setsockaddr_sock (&conn->local, conn->connection, 0);
	conn->mode = AN_MODE_BOUND;
	an_set_blocking (conn, oldblocking);
	return AN_ERROR_SUCCESS;
}

int
an_direct_listen (ANCONN conn)
{
	int ret;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_BOUND)
		return AN_ERROR_ORDER;
	ret = listen (conn->connection, 5);
	if (ret < 0) {
		perror ("listen");
		return AN_ERROR_NETWORK;
	}
	conn->mode = AN_MODE_LISTENING;
	return AN_ERROR_SUCCESS;
}

int
an_direct_accept (ANCONN conn, SOCKADDR * sa, int len)
{
	int ret;
	sl_t tmplen;
	PI_SA *tmpsa;
#ifdef WITH_IPV6
	int alen;
#endif
	unsigned short oldblocking;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_LISTENING)
		return AN_ERROR_ORDER;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	tmplen = len;

	ret = accept (conn->connection, (SOCKADDR *) sa, &tmplen);
	if (ret < 0) {
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_NETWORK;
	}

	tmpsa = (PI_SA *) sa;

#ifdef WITH_IPV6
	if (conn->peer.family == AF_INET6) {
		alen = 16;
	} else {
		alen = 4;
	}
	if ((tmpsa->sin6_family != conn->peer.family) ||
		(memcmp (&tmpsa->sin6_addr.s6_addr, &conn->peer.address, alen))) {
#else
	if ((tmpsa->sin_family != conn->peer.family) ||
		(memcmp (&tmpsa->sin_addr.s_addr, &conn->peer.address, 4))) {
#endif
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_NETWORK;
	}

	/* ok, have a connection, now store it. */
#ifdef WITH_IPV6
	conn->peer.port = tmpsa->sin6_port;
#else
	conn->peer.port = tmpsa->sin_port;
#endif

#ifdef _WIN32_
	closesocket (conn->connection);
#else
	close (conn->connection);
#endif
	conn->connection = ret;

	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_ACCEPTED;
	return AN_ERROR_SUCCESS;
}

int
an_direct_getsockname (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) &&
		(conn->mode != AN_MODE_BOUND) &&
		(conn->mode != AN_MODE_LISTENING) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->local, sa, len);
}

int
an_direct_getpeername (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_DIRECT)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->peer, sa, len);
}
