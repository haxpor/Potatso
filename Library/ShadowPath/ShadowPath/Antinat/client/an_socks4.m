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

int
an_socks4_close (ANCONN conn)
{
	return _an_generic_close (conn);
}

int
_an_socks4_processresponse (ANCONN conn, struct st_sock_info *info)
{
	unsigned char buf[10];
	int ret;
	ret = _an_generic_recv_all (conn, (void *) buf, 8);
	if (ret != AN_ERROR_SUCCESS)
		return ret;
	if ((buf[0] != 0x00) || (buf[1] != 90))
		return AN_ERROR_PROXY;
	if (info) {
		info->family = AF_INET;
		memcpy (info->address, &buf[4], 4);
		info->port = (unsigned short) (buf[2] * 256 + buf[3]);
	}
	return AN_ERROR_SUCCESS;
}

int
_an_socks4_performop (ANCONN conn, SOCKADDR * sa, int len, char op,
					  st_sock_info * info)
{
	unsigned short oldblocking;
	unsigned char buf[1024];
	int ret;
	SOCKADDR_IN *sin;

	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return AN_ERROR_INVALIDARG;
	if (sa->sa_family != AF_INET)
		return AN_ERROR_NOTSUPPORTED;	/* No IPv6 */
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;
	if ((op != 0x01) && (op != 0x02))
		return AN_ERROR_NOTSUPPORTED;
	if (!(conn->authmask & AN_AUTH_ANON))
		return AN_ERROR_NOTSUPPORTED;

	sin = (SOCKADDR_IN *) sa;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_rawconnect (conn);
	if (ret != AN_ERROR_SUCCESS) {
		an_set_blocking (conn, oldblocking);
		return ret;
	}

	buf[0] = 0x04;				/* Version */
	buf[1] = op;				/* Connect */
	memcpy (&buf[2], &sin->sin_port, 2);
	memcpy (&buf[4], &sin->sin_addr.s_addr, 4);
	ret = 8;
	if (conn->proxy_user != NULL) {
		strcpy ((char *) &buf[ret], conn->proxy_user);
		ret += strlen (conn->proxy_user);
	}
	buf[ret] = 0x00;
	ret = _an_generic_send_all (conn, (void *) buf, ret + 1);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks4_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	ret = _an_socks4_processresponse (conn, info);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks4_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	an_set_blocking (conn, oldblocking);
	switch (op) {
	case 1:
		conn->mode = AN_MODE_CONNECTED;
		break;
	case 2:
		conn->mode = AN_MODE_BOUND;
		break;
	}
	return AN_ERROR_SUCCESS;
}

int
an_socks4_connect_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	int ret;
	ret = _an_socks4_performop (conn, sa, len, 1, &conn->local);
	if (ret == AN_ERROR_SUCCESS) {
		_an_setsockaddr (&conn->peer, sa, len);
		/* Is wrong information better or worse than nothing?
		 * Non-Antinat servers don't return the public local address
		 * on a connect request, should we get the private local address
		 * instead?  I'm settling on nothing better than wrong, so
		 * without an Antinat server, you might get zip.
		 */
	}
	return ret;
}

int
an_socks4_bind_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	int ret;
	ret = _an_socks4_performop (conn, sa, len, 2, &conn->local);
	if (ret == AN_ERROR_SUCCESS) {
		_an_setsockaddr (&conn->peer, sa, len);
	}
	return ret;
}

int
_an_socks4_resolvehost (ANCONN conn, const char *hostname,
						unsigned short port, char op)
{
	SOCKADDR_IN sin;
	HOSTENT he;
	char buf2[1024];
	int perrno;
	PHOSTENT phe;
	int ret;

	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	an_gethostbyname (hostname, &he, buf2, sizeof (buf2), &phe, &perrno);
	if (phe == NULL)
		return AN_ERROR_NETWORK;

	memset (&sin, 0, sizeof (sin));
	sin.sin_family = AF_INET;
	memcpy (&sin.sin_addr.s_addr, phe->h_addr, 4);
	sin.sin_port = htons (port);
	ret = _an_socks4_performop (conn, (SOCKADDR *) & sin, sizeof (sin),
								op, &conn->local);
	if (ret == AN_ERROR_SUCCESS) {
		_an_setsockaddr (&conn->peer, (SOCKADDR *) & sin, sizeof (sin));
	}
	return ret;
}

int
an_socks4_connect_tohostname (ANCONN conn, const char *hostname,
							  unsigned short port)
{
	return _an_socks4_resolvehost (conn, hostname, port, 1);
}

int
an_socks4_bind_tohostname (ANCONN conn, const char *hostname,
						   unsigned short port)
{
	return _an_socks4_resolvehost (conn, hostname, port, 2);
}

int
an_socks4_recv (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return -1;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return -1;

	return _an_generic_recv (conn, buf, len, flags);
}

int
an_socks4_send (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return -1;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return -1;
	return _an_generic_send (conn, buf, len, flags);
}

int
an_socks4_getsockname (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) &&
		(conn->mode != AN_MODE_BOUND) &&
		(conn->mode != AN_MODE_LISTENING) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->local, sa, len);
}

int
an_socks4_getpeername (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->peer, sa, len);
}

int
an_socks4_listen (ANCONN conn)
{
	if (conn->mode != AN_MODE_BOUND)
		return AN_ERROR_ORDER;
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return AN_ERROR_INVALIDARG;
	conn->mode = AN_MODE_LISTENING;
	return AN_ERROR_SUCCESS;
}

int
an_socks4_accept (ANCONN conn, SOCKADDR * sa, int len)
{
	unsigned short oldblocking;
	int ret;
	if (conn->proxy_type != AN_SERV_SOCKS4)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_BOUND) && (conn->mode != AN_MODE_LISTENING))
		return AN_ERROR_ORDER;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks4_processresponse (conn, &conn->peer);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks4_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_ACCEPTED;
	if ((sa != NULL) && (len > 0)) {
		return an_socks4_getpeername (conn, sa, len);
	}
	return AN_ERROR_SUCCESS;
}
