/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_internals.h"

#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif

#include "antinat.h"

ANCONN
an_new_connection ()
{
	ANCONN tmp;
	tmp = (ANCONN) malloc (sizeof (st_proxy));
	if (tmp == NULL)
		return NULL;
	memset (tmp, 0, sizeof (st_proxy));
	tmp->connection = (SOCKET) AN_INVALID_CONNECTION;
	tmp->blocking = AN_CONN_BLOCKING;
	tmp->proxy_type = AN_SERV_DIRECT;
	tmp->proxy_hostname = NULL;
	tmp->mode = AN_MODE_NONE;
	tmp->proxy_user = NULL;
	tmp->proxy_pass = NULL;
	tmp->authmask = 0xffffffff;
	tmp->local.family = AN_INVALID_FAMILY;
	tmp->peer.family = AN_INVALID_FAMILY;
	an_set_proxy_url (tmp, getenv ("AN_PROXY"));
	an_set_credentials (tmp, getenv ("AN_USER"), getenv ("AN_PASS"));
	return tmp;
}

int
an_set_proxy (ANCONN conn, unsigned short type,
			  unsigned short packet_family, const char *hostname,
			  unsigned short port)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (hostname == NULL)
		return AN_ERROR_INVALIDARG;
	if ((type != AN_SERV_SOCKS5) &&
		(type != AN_SERV_SOCKS4) && (type != AN_SERV_SSL))
		return AN_ERROR_NOTSUPPORTED;
	conn->proxy_type = type;
	switch (packet_family) {
	case AN_PF_INET:
		conn->proxy_pf = AF_INET;
		break;
#ifdef WITH_IPV6
	case AN_PF_INET6:
		conn->proxy_pf = AF_INET6;
		break;
#endif
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
	conn->proxy_port = port;
	if (conn->proxy_hostname != NULL)
		free (conn->proxy_hostname);
	conn->proxy_hostname = (char *) malloc (strlen (hostname) + 1);
	if (conn->proxy_hostname == NULL)
		return AN_ERROR_NOMEM;
	strcpy (conn->proxy_hostname, hostname);

	return AN_ERROR_SUCCESS;
}

int
an_unset_proxy (ANCONN conn)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	conn->proxy_type = AN_SERV_DIRECT;
	conn->proxy_pf = AN_PF_INET;
	if (conn->proxy_hostname != NULL)
		free (conn->proxy_hostname);
	conn->proxy_hostname = NULL;
	conn->proxy_port = 0;

	return AN_ERROR_SUCCESS;

}

int
an_set_proxy_url (ANCONN conn, const char *url)
{
	unsigned short type;
	char buf[200];
	unsigned short port;
	char *hoststart;
	char *hostend;
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (url == NULL)
		return AN_ERROR_INVALIDARG;
	hoststart = strstr (url, "://");
	type = AN_SERV_DIRECT;
	port = 1080;
	if (hoststart) {
		strncpy (buf, url, hoststart - url);
		buf[hoststart - url] = '\0';
		if (strcmp (buf, "socks4") == 0)
			type = AN_SERV_SOCKS4;
		if (strcmp (buf, "socks5") == 0)
			type = AN_SERV_SOCKS5;
		if (strcmp (buf, "ssl") == 0)
			type = AN_SERV_SSL;
		if (strcmp (buf, "https") == 0)
			type = AN_SERV_SSL;
		hoststart += 3;
		hostend = strchr (hoststart, ':');
		if (hostend) {
			port = (unsigned short) atoi (hostend + 1);
			strncpy (buf, hoststart, hostend - hoststart);
			buf[hostend - hoststart] = '\0';
		} else {
			strcpy (buf, hoststart);
		}
		return an_set_proxy (conn, type, AN_PF_INET, buf, port);
	}
	return AN_ERROR_SUCCESS;
}

int
an_connect_tohostname (ANCONN conn, const char *hostname, unsigned short port)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_connect_tohostname (conn, hostname, port);
	case AN_SERV_SOCKS4:
		return an_socks4_connect_tohostname (conn, hostname, port);
	case AN_SERV_SOCKS5:
		return an_socks5_connect_tohostname (conn, hostname, port);
	case AN_SERV_SSL:
		return an_ssl_connect_tohostname (conn, hostname, port);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_connect_tosockaddr (ANCONN conn, SOCKADDR * sa, int sl)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_connect_tosockaddr (conn, sa, sl);
	case AN_SERV_SOCKS4:
		return an_socks4_connect_tosockaddr (conn, sa, sl);
	case AN_SERV_SOCKS5:
		return an_socks5_connect_tosockaddr (conn, sa, sl);
	case AN_SERV_SSL:
		return an_ssl_connect_tosockaddr (conn, sa, sl);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}

}

int
an_bind_tohostname (ANCONN conn, const char *hostname, unsigned short port)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_bind_tohostname (conn, hostname, port);
	case AN_SERV_SOCKS4:
		return an_socks4_bind_tohostname (conn, hostname, port);
	case AN_SERV_SOCKS5:
		return an_socks5_bind_tohostname (conn, hostname, port);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_bind_tosockaddr (ANCONN conn, SOCKADDR * sa, int sl)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_bind_tosockaddr (conn, sa, sl);
	case AN_SERV_SOCKS4:
		return an_socks4_bind_tosockaddr (conn, sa, sl);
	case AN_SERV_SOCKS5:
		return an_socks5_bind_tosockaddr (conn, sa, sl);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}

}

int
an_getsockname (ANCONN conn, SOCKADDR * sa, int sl)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_getsockname (conn, sa, sl);
	case AN_SERV_SOCKS4:
		return an_socks4_getsockname (conn, sa, sl);
	case AN_SERV_SOCKS5:
		return an_socks5_getsockname (conn, sa, sl);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_getpeername (ANCONN conn, SOCKADDR * sa, int sl)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (sa == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_getpeername (conn, sa, sl);
	case AN_SERV_SOCKS4:
		return an_socks4_getpeername (conn, sa, sl);
	case AN_SERV_SOCKS5:
		return an_socks5_getpeername (conn, sa, sl);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_listen (ANCONN conn)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_listen (conn);
	case AN_SERV_SOCKS4:
		return an_socks4_listen (conn);
	case AN_SERV_SOCKS5:
		return an_socks5_listen (conn);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_accept (ANCONN conn, SOCKADDR * sa, int len)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_accept (conn, sa, len);
	case AN_SERV_SOCKS4:
		return an_socks4_accept (conn, sa, len);
	case AN_SERV_SOCKS5:
		return an_socks5_accept (conn, sa, len);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_close (ANCONN conn)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_socks4_close (conn);
	case AN_SERV_SOCKS4:
		return an_socks4_close (conn);
	case AN_SERV_SOCKS5:
		return an_socks5_close (conn);
	case AN_SERV_SSL:
		return an_ssl_close (conn);
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
}

int
an_destroy (ANCONN conn)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	an_close (conn);

	conn->proxy_type = AN_SERV_DIRECT;

	if (conn->proxy_user)
		free (conn->proxy_user);
	if (conn->proxy_pass)
		free (conn->proxy_pass);

	if (conn->proxy_hostname != NULL)
		free (conn->proxy_hostname);
	free (conn);
	return AN_ERROR_SUCCESS;
}

int
an_clear_authschemes (ANCONN conn)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	conn->authmask = 0;
	return AN_ERROR_SUCCESS;
}

int
an_set_authscheme (ANCONN conn, unsigned int scheme)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;
	if (scheme > AN_AUTH_MAX)
		return AN_ERROR_INVALIDARG;
	if (conn->authmask & AN_AUTH_UNDEF)
		an_clear_authschemes (conn);
	conn->authmask = conn->authmask | (1 << scheme);
	return AN_ERROR_SUCCESS;
}

int
an_set_credentials (ANCONN conn, const char *user, const char *pass)
{
	if (conn == NULL)
		return AN_ERROR_INVALIDARG;

	if (conn->proxy_user != NULL)
		free (conn->proxy_user);
	if (conn->proxy_pass != NULL)
		free (conn->proxy_pass);

	if (user == NULL) {
		conn->proxy_user = NULL;
	} else {
		conn->proxy_user = (char *) malloc (strlen (user) + 1);
		if (conn->proxy_user == NULL)
			return AN_ERROR_NOMEM;
		strcpy (conn->proxy_user, user);
	}

	if (pass == NULL) {
		conn->proxy_pass = NULL;
	} else {
		conn->proxy_pass = (char *) malloc (strlen (pass) + 1);
		if (conn->proxy_pass == NULL)
			return AN_ERROR_NOMEM;
		strcpy (conn->proxy_pass, pass);
	}

	return AN_ERROR_SUCCESS;
}

int
an_send (ANCONN conn, void *buf, int len, int flags)
{
	if (conn == NULL)
		return -1;
	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_send (conn, buf, len, flags);
	case AN_SERV_SOCKS4:
		return an_socks4_send (conn, buf, len, flags);
	case AN_SERV_SOCKS5:
		return an_socks5_send (conn, buf, len, flags);
	case AN_SERV_SSL:
		return an_ssl_send (conn, buf, len, flags);
	default:
		return -1;
	}
}

int
an_recv (ANCONN conn, void *buf, int len, int flags)
{
	if (conn == NULL)
		return -1;
	switch (conn->proxy_type) {
	case AN_SERV_DIRECT:
		return an_direct_recv (conn, buf, len, flags);
	case AN_SERV_SOCKS4:
		return an_socks4_recv (conn, buf, len, flags);
	case AN_SERV_SOCKS5:
		return an_socks5_recv (conn, buf, len, flags);
	case AN_SERV_SSL:
		return an_ssl_recv (conn, buf, len, flags);
	default:
		return -1;
	}
}
