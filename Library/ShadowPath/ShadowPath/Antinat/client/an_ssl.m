/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_internals.h"
#include <arpa/inet.h>
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif

#include "antinat.h"
#include "an_core.h"

static const char *b64t =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

int
_an_ssl_b64enc (const char *raw, char *enc)
{
	unsigned char inblk[3];
	int i;
	i = 0;
	while (*raw) {
		inblk[i] = (unsigned char) *raw;
		i++;
		if (i == 3) {
			enc[0] = b64t[(inblk[0] & 0xfc) >> 2];
			enc[1] =
				b64t[((inblk[0] & 0x03) << 4) + ((inblk[1] & 0xf0) >> 4)];
			enc[2] =
				b64t[((inblk[1] & 0x0f) << 2) + ((inblk[2] & 0xc0) >> 6)];
			enc[3] = b64t[(inblk[2] & 0x3f)];
			i = 0;
			enc += 4;
		}
		raw++;
	}
	switch (i) {
	case 2:
		enc[0] = b64t[(inblk[0] & 0xfc) >> 2];
		enc[1] = b64t[((inblk[0] & 0x03) << 4) + ((inblk[1] & 0xf0) >> 4)];
		enc[2] = b64t[((inblk[1] & 0x0f) << 2)];
		enc[3] = '=';
		enc += 4;
		break;
	case 1:
		enc[0] = b64t[(inblk[0] & 0xfc) >> 2];
		enc[1] = b64t[((inblk[0] & 0x03) << 4)];
		enc[2] = '=';
		enc[3] = '=';
		enc += 4;
		break;
	}
	enc[0] = '\0';
	return AN_ERROR_SUCCESS;
}

int
an_ssl_close (ANCONN conn)
{
	return _an_generic_close (conn);
}

int
an_ssl_connect_tosockaddr (ANCONN conn, SOCKADDR * sa, int len)
{
	char buf[20];
	SOCKADDR_IN *sin;
	int ret;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa->sa_family != AF_INET)
		return AN_ERROR_NOTSUPPORTED;

	sin = (SOCKADDR_IN *) sa;

//	sprintf (buf, "%u.%u.%u.%u",
//			 (unsigned int) (sin->sin_addr.s_addr % 0xff000000) / 0x01000000,
//			 (unsigned int) (sin->sin_addr.s_addr % 0xff0000) / 0x010000,
//			 (unsigned int) (sin->sin_addr.s_addr % 0xff00) / 0x0100,
//			 (unsigned int) sin->sin_addr.s_addr % 0xff);
    inet_ntop(AF_INET, &(sin->sin_addr), buf, sizeof(SOCKADDR_IN));
	ret = an_ssl_connect_tohostname (conn, buf, ntohs (sin->sin_port));
	if (ret == AN_ERROR_SUCCESS) {
		_an_setsockaddr (&conn->peer, sa, len);
	}
	return ret;
}

int
an_ssl_connect_tohostname (ANCONN conn, const char *hostname,
						   unsigned short port)
{
	unsigned short oldblocking;
	int ret;
	char buf[1024];
	char *cptr;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_type != AN_SERV_SSL)
		return AN_ERROR_INVALIDARG;
	if (conn->proxy_user == NULL && !(conn->authmask & (1 << AN_AUTH_ANON)))
		return AN_ERROR_NOTSUPPORTED;
	if (conn->proxy_user != NULL && !(conn->authmask & (1 << AN_AUTH_ANON)) &&
		!(conn->authmask & (1 << AN_AUTH_BASIC)))
		return AN_ERROR_NOTSUPPORTED;

	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);

	ret = _an_rawconnect (conn);
	if (ret != AN_ERROR_SUCCESS) {
		an_set_blocking (conn, oldblocking);
		return ret;
	}

	if (conn->proxy_user != NULL && (conn->authmask & (1 << AN_AUTH_BASIC))) {
		char authbuf[512];
		char rawauthbuf[512];
		/* Sanity check. */
		if (strlen (conn->proxy_user) < 150) {
			strcpy (rawauthbuf, conn->proxy_user);
			strcat (rawauthbuf, ":");
			if (conn->proxy_pass && (strlen (conn->proxy_pass) < 150)) {
				strcat (rawauthbuf, conn->proxy_pass);
			}
		} else {
			strcpy (rawauthbuf, ":");
		}

		_an_ssl_b64enc (rawauthbuf, authbuf);

		sprintf (buf,
				 "CONNECT %s:%i HTTP/1.0\r\nProxy-Authorization: Basic %s\r\n\r\n",
				 hostname, port, authbuf);
	} else {
		sprintf (buf, "CONNECT %s:%i HTTP/1.0\r\n\r\n", hostname, port);
	}

	ret = _an_generic_send_all (conn, buf, strlen (buf));
	if (ret != AN_ERROR_SUCCESS) {
		an_ssl_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}

	ret = _an_generic_getline (conn, buf, sizeof (buf));
	if (ret != AN_ERROR_SUCCESS) {
		an_ssl_close (conn);
		an_set_blocking (conn, oldblocking);
		return ret;
	}
	cptr = strchr (buf, ' ');
	if (cptr) {
		cptr++;
		ret = atoi (cptr);
		if (ret != 200) {
			/* Connect failed :( */
			an_ssl_close (conn);
			an_set_blocking (conn, oldblocking);
			return AN_ERROR_PROXY;
		}
	} else {
		/* No space in response, bad response */
		an_ssl_close (conn);
		an_set_blocking (conn, oldblocking);
		return AN_ERROR_PROXY;
	}
	while (strlen (buf) > 0) {
		ret = _an_generic_getline (conn, buf, sizeof (buf));
		if (ret != AN_ERROR_SUCCESS) {
			an_ssl_close (conn);
			an_set_blocking (conn, oldblocking);
			return ret;
		}
	}

	an_set_blocking (conn, oldblocking);
	conn->mode = AN_MODE_CONNECTED;
	return AN_ERROR_SUCCESS;
}

int
an_ssl_recv (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	return _an_generic_recv (conn, buf, len, flags);
}

int
an_ssl_send (ANCONN conn, void *buf, int len, int flags)
{
	if (conn->connection == AN_INVALID_CONNECTION)
		return -1;
	return _an_generic_send (conn, buf, len, flags);
}
