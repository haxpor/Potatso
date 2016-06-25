/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_internals.h"
#include "iscmd5.h"

#include "antinat.h"
#include "an_core.h"

int
an_socks5_close (ANCONN conn)
{
	return _an_generic_close (conn);
}

int
_an_socks5_hmacmd5_chap (const unsigned char *challenge, int challen,
						 const char *passwd, unsigned char *response)
{
	int i;
	unsigned char Kxoripad[65];
	unsigned char Kxoropad[65];
	isc_md5_t ctx;
	int pwlen;
	char *pwinput;
	char md5buf[16];

	pwinput = (char *) passwd;
	pwlen = strlen (passwd);
	if (pwlen > 64) {
		isc_md5_init (&ctx);
		isc_md5_update (&ctx, (unsigned char *) passwd, strlen (passwd));
		isc_md5_final (&ctx, (unsigned char *) md5buf);
		pwinput = (char *) md5buf;
		pwlen = 16;
	}

	memset (Kxoripad, 0, sizeof (Kxoripad));
	memset (Kxoropad, 0, sizeof (Kxoropad));
	memcpy (Kxoripad, pwinput, pwlen);
	memcpy (Kxoropad, pwinput, pwlen);
	for (i = 0; i < 64; i++) {
		Kxoripad[i] ^= 0x36;
		Kxoropad[i] ^= 0x5c;
	}
	isc_md5_init (&ctx);
	isc_md5_update (&ctx, Kxoripad, 64);
	isc_md5_update (&ctx, challenge, challen);
	isc_md5_final (&ctx, (unsigned char *) Kxoripad);

	isc_md5_init (&ctx);
	isc_md5_update (&ctx, Kxoropad, 64);
	isc_md5_update (&ctx, Kxoripad, 16);
	isc_md5_final (&ctx, response);

	return AN_ERROR_SUCCESS;
}

int
_an_socks5_auth_usernamepassword (ANCONN conn, unsigned char *buf)
{
	int ret;
	int upto;
	/* Username and password authentication */
	if (conn->proxy_user == NULL)
		return AN_ERROR_PROXY;

	buf[0] = 0x01;
	buf[1] = (unsigned char) strlen (conn->proxy_user);
	strcpy ((char *) &buf[2], conn->proxy_user);
	upto = strlen (conn->proxy_user) + 2;

	if (conn->proxy_pass == NULL) {
		buf[upto] = 0;
		upto++;
	} else {
		buf[upto] = (unsigned char) strlen (conn->proxy_pass);
		upto++;
		strcpy ((char *) &buf[upto], conn->proxy_pass);
		upto += strlen (conn->proxy_pass);
	}

	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	ret = _an_generic_recv_all (conn, (void *) buf, 2);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	/* 0x00 was sent back by antinat thru 0.66 :( */
	/* Don't care 'bout it anymore.  Upgrade. */
	if ((buf[0] != 0x01) || (buf[1] != 0x00))
		return AN_ERROR_AUTH;
	return AN_ERROR_SUCCESS;
}

int
_an_socks5_auth_chap (ANCONN conn, unsigned char *buf)
{
	int ret;
	int upto;
	int navas;
	char minibuf[4];
	unsigned char response[20];
	/* CHAP authentication */
	if (conn->proxy_user == NULL)
		return AN_ERROR_PROXY;
	if (conn->proxy_pass == NULL)
		return AN_ERROR_NOTSUPPORTED;

	buf[0] = 0x01;				/* Version */
	buf[1] = 0x02;				/* Number of attributes sent */
	buf[2] = 0x11;				/* Algorithms list */
	buf[3] = 0x01;				/* Only one CHAP algorithm */
	buf[4] = 0x85;				/* ...and it's HMAC-MD5, the core one */
	buf[5] = 0x02;				/* Username */
	buf[6] = (unsigned char) strlen (conn->proxy_user);
	strcpy ((char *) &buf[7], conn->proxy_user);
	upto = strlen (conn->proxy_user) + 7;

	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	/* We return from this ourselves if anything happens */
	while (1) {


		ret = _an_generic_recv_all (conn, (void *) buf, 2);
		if (ret != AN_ERROR_SUCCESS)
			return ret;
		/* Different version or nothing to say */
		if ((buf[0] != 0x01) || (buf[1] == 0x00)) {
			return AN_ERROR_PROXY;
		}
		navas = buf[1];
		for (upto = 0; upto < navas; upto++) {
			/* Get cmd */
			ret = _an_generic_recv_all (conn, (void *) minibuf, 2);
			if (ret != AN_ERROR_SUCCESS)
				return ret;

			/* Get data */
			ret = _an_generic_recv_all (conn, (void *) buf, minibuf[1]);
			if (ret != AN_ERROR_SUCCESS)
				return ret;

			switch (minibuf[0]) {
			case 0x00:
				if (buf[0] == 0x00)
					return AN_ERROR_SUCCESS;
				return AN_ERROR_AUTH;
				break;
			case 0x03:
				_an_socks5_hmacmd5_chap (buf, minibuf[1], conn->proxy_pass,
										 response);
				buf[0] = 0x01;	/* Version */
				buf[1] = 0x01;	/* One attribute */
				buf[2] = 0x04;	/* Response */
				buf[3] = 0x10;	/* Length */
				memcpy ((char *) &buf[4], response, 16);
				ret = _an_generic_send_all (conn, (void *) buf, 20);
				if (ret != AN_ERROR_SUCCESS)
					return ret;
				break;
			case 0x11:
				if (buf[0] != 0x85)
					return AN_ERROR_NOTSUPPORTED;
				break;
			}
		}
	}
	return AN_ERROR_PROXY;
}


int
_an_socks5_connect_real_part1 (ANCONN conn, unsigned char *buf)
{
	int ret;
	int i, j;


	buf[0] = 0x05;

	j = 2;
	for (i = 0; i <= AN_AUTH_MAX; i++)
		if (conn->authmask & (1 << i)) {
			switch (i) {
			case AN_AUTH_ANON:
				buf[j++] = 0x00;
				break;
			case AN_AUTH_CLEARTEXT:
				if (conn->proxy_user != NULL)
					buf[j++] = 0x02;
				break;
			case AN_AUTH_CHAP:
				if (conn->proxy_user != NULL)
					buf[j++] = 0x03;
				break;
			}
		}

	buf[1] = (unsigned char) j - 2;
	if (buf[1] == 0)
		return AN_ERROR_INVALIDARG;

	ret = _an_rawconnect (conn);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	ret = _an_generic_send_all (conn, (void *) buf, buf[1] + 2);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	ret = _an_generic_recv_all (conn, (void *) buf, 2);
	if (ret != AN_ERROR_SUCCESS)
		return ret;

	if ((buf[0] != 0x05)
		|| !((buf[1] == 0x00) || (buf[1] == 0x02) || (buf[1] = 0x03)))
		return AN_ERROR_PROXY;

	switch (buf[1]) {
	case 0:
		/* Anonymous ok */
		ret = AN_ERROR_SUCCESS;
		break;
	case 2:
		/* Verify username/password */
		ret = _an_socks5_auth_usernamepassword (conn, buf);
		break;
	case 3:
		/* Verify CHAP */
		ret = _an_socks5_auth_chap (conn, buf);
		break;
	}
	return ret;
}

int
_an_socks5_connect_real_part2 (ANCONN conn, unsigned char *buf,
							   st_sock_info * info)
{
	int ret;
	int len;
	ret = _an_generic_recv_all (conn, (void *) buf, 4);
	if (ret != AN_ERROR_SUCCESS)
		return ret;
	if ((buf[0] != 0x05) || (buf[1] != 0x00))
		return AN_ERROR_PROXY;
	switch (buf[3]) {
	case 0x01:
		info->family = AF_INET;
		len = 4;				/* IPv4 */
		break;
#ifdef WITH_IPV6
	case 0x04:
		info->family = AF_INET6;
		len = 16;				/* IPv6 */
		break;
#endif
	case 0x03:
		info->family = AN_INVALID_FAMILY;
		ret = _an_generic_recv_all (conn, (void *) buf, 1);
		if (ret != AN_ERROR_SUCCESS)
			return ret;
		len = buf[0];
		break;
	default:
		return AN_ERROR_PROXY;
	}

	ret = _an_generic_recv_all (conn, buf, len + 2);
	if (info->family != AN_INVALID_FAMILY) {
		memcpy (info->address, buf, len);
		info->port = (unsigned short) (buf[len] * 256 + buf[len + 1]);
	}
	if (ret != AN_ERROR_SUCCESS)
		return ret;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_connect_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	int ret;
	int upto;
	unsigned char buf[1024];
	unsigned short oldblocking;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;
	if ((sa->sa_family != AF_INET)
#ifdef WITH_IPV6
		&& (sa->sa_family != AF_INET6)
#endif
		)
		return AN_ERROR_NOTSUPPORTED;

	upto = 0;					/* Should never be used */

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks5_connect_real_part1 (conn, buf);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	buf[0] = 0x05;				/* Version */
	buf[1] = 0x01;				/* Connect */
	buf[2] = 0x00;				/* Reserved */
	if (sa->sa_family == AF_INET) {
		SOCKADDR_IN *sin;
		sin = (SOCKADDR_IN *) sa;
		buf[3] = 0x01;			/* IPv4-based connection */
		memcpy ((char *) &buf[4], &sin->sin_addr.s_addr, 4);
		memcpy ((char *) &buf[8], &sin->sin_port, 2);
		upto = 10;
#ifdef WITH_IPV6
	} else if (sa->sa_family == AF_INET6) {
		SOCKADDR_IN6 *sin;
		sin = (SOCKADDR_IN6 *) sa;
		buf[3] = 0x04;			/* IPv6-based connection */
		memcpy ((char *) &buf[4], sin->sin6_addr.s6_addr, 16);
		memcpy ((char *) &buf[20], &sin->sin6_port, 2);
		upto = 22;
#endif
	}
	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	ret = _an_socks5_connect_real_part2 (conn, buf, &conn->local);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	_an_setsockaddr (&conn->peer, sa, len);
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_CONNECTED;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_connect_tohostname (ANCONN conn, const char *hostname,
							  unsigned short port)
{
	int ret;
	int upto;
	unsigned char buf[1024];
	unsigned short oldblocking;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks5_connect_real_part1 (conn, buf);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	buf[0] = 0x05;				/* Version */
	buf[1] = 0x01;				/* Connect */
	buf[2] = 0x00;				/* Reserved */
	buf[3] = 0x03;				/* Name-based connection */
	buf[4] = (unsigned char) strlen (hostname);	/* Length of name */
	strcpy ((char *) &buf[5], hostname);	/* Name */
	upto = 5 + strlen (hostname);
	buf[upto] = (unsigned char) ((port & 0xff00) / 0x100);
	upto++;
	buf[upto] = (unsigned char) ((port & 0xff));
	upto++;
	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	ret = _an_socks5_connect_real_part2 (conn, buf, &conn->local);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_CONNECTED;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_bind_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	int ret;
	int upto;
	unsigned char buf[1024];
	unsigned short oldblocking;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;
	if ((sa->sa_family != AF_INET)
#ifdef WITH_IPV6
		&& (sa->sa_family != AF_INET6)
#endif
		)
		return AN_ERROR_NOTSUPPORTED;

	upto = 0;					/* Should never be used */

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks5_connect_real_part1 (conn, buf);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	buf[0] = 0x05;				/* Version */
	buf[1] = 0x02;				/* Bind */
	buf[2] = 0x00;				/* Reserved */
	if (sa->sa_family == AF_INET) {
		SOCKADDR_IN *sin;
		sin = (SOCKADDR_IN *) sa;
		buf[3] = 0x01;			/* IPv4-based connection */
		memcpy ((char *) &buf[4], &sin->sin_addr.s_addr, 4);
		buf[8] = (unsigned char) ((sin->sin_port & 0xff00) / 0x100);
		buf[9] = (unsigned char) (sin->sin_port & 0xff);
		upto = 10;
#ifdef WITH_IPV6
	} else if (sa->sa_family == AF_INET6) {
		SOCKADDR_IN6 *sin;
		sin = (SOCKADDR_IN6 *) sa;
		buf[3] = 0x04;			/* IPv6-based connection */
		memcpy ((char *) &buf[4], sin->sin6_addr.s6_addr, 16);
		buf[20] = (unsigned char) ((sin->sin6_port & 0xff00) / 0x100);
		buf[21] = (unsigned char) (sin->sin6_port & 0xff);
		upto = 22;
#endif
	}
	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	ret = _an_socks5_connect_real_part2 (conn, buf, &conn->local);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	_an_setsockaddr (&conn->peer, sa, len);
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_BOUND;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_bind_tohostname (ANCONN conn, const char *hostname,
						   unsigned short port)
{
	int ret;
	int upto;
	unsigned char buf[1024];
	unsigned short oldblocking;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if (conn->mode != AN_MODE_NONE)
		return AN_ERROR_ORDER;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks5_connect_real_part1 (conn, buf);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	buf[0] = 0x05;				/* Version */
	buf[1] = 0x02;				/* Bind */
	buf[2] = 0x00;				/* Reserved */
	buf[3] = 0x03;				/* Name-based connection */
	buf[4] = (unsigned char) strlen (hostname);	/* Length of name */
	strcpy ((char *) &buf[5], hostname);	/* Name */
	upto = 5 + strlen (hostname);
	buf[upto] = (unsigned char) ((port & 0xff00) / 0x100);
	upto++;
	buf[upto] = (unsigned char) (port & 0xff);
	upto++;
	ret = _an_generic_send_all (conn, (void *) buf, upto);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	ret = _an_socks5_connect_real_part2 (conn, buf, &conn->local);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_BOUND;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_recv (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return -1;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return -1;
	return _an_generic_recv (conn, buf, len, flags);
}

int
an_socks5_send (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return -1;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return -1;
	return _an_generic_send (conn, buf, len, flags);
}

int
an_socks5_getsockname (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) &&
		(conn->mode != AN_MODE_BOUND) &&
		(conn->mode != AN_MODE_LISTENING) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->local, sa, len);
}

int
an_socks5_getpeername (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_CONNECTED) && (conn->mode != AN_MODE_ACCEPTED))
		return AN_ERROR_ORDER;
	return _an_getsockaddr (&conn->peer, sa, len);
}

int
an_socks5_listen (ANCONN conn)
{
	if (conn->mode != AN_MODE_BOUND)
		return AN_ERROR_ORDER;
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	conn->mode = AN_MODE_LISTENING;
	return AN_ERROR_SUCCESS;
}

int
an_socks5_accept (ANCONN conn, SOCKADDR * sa, int len)
{
	unsigned short oldblocking;
	int ret;
	unsigned char buf[1024];
	if (conn->proxy_type != AN_SERV_SOCKS5)
		return AN_ERROR_INVALIDARG;
	if ((conn->mode != AN_MODE_BOUND) && (conn->mode != AN_MODE_LISTENING))
		return AN_ERROR_ORDER;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_socks5_connect_real_part2 (conn, buf, &conn->peer);
	if (ret != AN_ERROR_SUCCESS) {
		an_socks5_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_ACCEPTED;
	if ((sa != NULL) && (len > 0)) {
		return an_socks5_getpeername (conn, sa, len);
	}
	return AN_ERROR_SUCCESS;
}
