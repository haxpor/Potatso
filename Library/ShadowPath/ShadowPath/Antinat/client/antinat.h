/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#ifndef _ANTINAT_H
#define _ANTINAT_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WIN32_
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#else
#include <winsock.h>
#endif

//#ifdef __AN_KERNEL
/* This part is used if we're compiling the library itself. */

/* A reserved value to indicate no connection */
#define AN_INVALID_CONNECTION (-1)

#define AN_INVALID_FAMILY (-1)

#define AN_MODE_NONE       0
#define AN_MODE_CONNECTED  1
#define AN_MODE_BOUND      2
#define AN_MODE_LISTENING  3
#define AN_MODE_ACCEPTED   4
#define AN_MODE_ASSOCIATED 5

#ifndef _WIN32_
	typedef int SOCKET;
#endif

	typedef struct st_sock_info {
		int family;
		unsigned short port;
		char address[16];
	} st_sock_info;

	typedef struct st_proxy {
		SOCKET connection;
		char *proxy_hostname;
		char *proxy_user;
		char *proxy_pass;
		unsigned short proxy_port;
		unsigned short proxy_type;
		unsigned short proxy_pf;
		unsigned short blocking;
		unsigned short mode;
		st_sock_info local;
		st_sock_info peer;
		unsigned short udpport;
		unsigned int authmask;
	} st_proxy;

	typedef st_proxy *ANCONN;
//#else
///* This is for the world at large. */
//	typedef void *ANCONN;
//
//#endif

/* The header version number.  Compare to the getVersion() function. */
#define AN_VERSION 0x00000300

/* Is socket blocking or not? */
#define AN_CONN_BLOCKING    1
#define AN_CONN_NONBLOCKING 0

/* Packet family */
#define AN_PF_INET          0
#define AN_PF_INET6         1

/* Type of proxy */
#define AN_SERV_SOCKS5      5
#define AN_SERV_SOCKS4      4
#define AN_SERV_SSL         1
#define AN_SERV_HTTPS       1
#define AN_SERV_DIRECT      0

/* Authentication schemes */
#define AN_AUTH_ANON        1
#define AN_AUTH_CLEARTEXT   2
#define AN_AUTH_BASIC       2
#define AN_AUTH_CHAP        3

#
/* Error values. */
#define AN_ERROR_SUCCESS 0
#define AN_ERROR_NOTSUPPORTED 0x100
#define AN_ERROR_INVALIDARG   0x101
#define AN_ERROR_NOMEM        0x102
#define AN_ERROR_NETWORK      0x103
#define AN_ERROR_PROXY        0x104
#define AN_ERROR_AUTH         0x105
#define AN_ERROR_ORDER        0x106
#define AN_ERROR_NAMERESOLVE  0x107

	void AN_FD_CLR (ANCONN, fd_set *);
	int AN_FD_SET (ANCONN, fd_set *, int);
	int AN_FD_ISSET (ANCONN, fd_set *);

	int an_accept (ANCONN, struct sockaddr *, int);
	int an_bind_tohostname (ANCONN, const char *, unsigned short);
	int an_bind_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_clear_authschemes (ANCONN);
	int an_close (ANCONN);
	int an_connect_tohostname (ANCONN, const char *, unsigned short);
	int an_connect_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_destroy (ANCONN);
	int an_direct_accept (ANCONN, struct sockaddr *, int);
	int an_direct_bind_tohostname (ANCONN, const char *, unsigned short);
	int an_direct_bind_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_direct_connect_tohostname (ANCONN, const char *, unsigned short);
	int an_direct_connect_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_direct_close (ANCONN);
	int an_direct_getpeername (ANCONN, struct sockaddr *, int);
	int an_direct_getsockname (ANCONN, struct sockaddr *, int);
	int an_direct_listen (ANCONN);
	int an_direct_recv (ANCONN, void *, int, int);
	int an_direct_send (ANCONN, void *, int, int);
	char *an_geterror (int);
	int an_gethostbyname (const char *, struct hostent *, char *, int,
						  struct hostent **ret, int *);
	int an_getpeername (ANCONN, struct sockaddr *, int);
	int an_getsockname (ANCONN, struct sockaddr *, int);
	unsigned int an_getversion ();
	int an_listen (ANCONN);
	ANCONN an_new_connection ();
	int an_recv (ANCONN, void *, int, int);
	int an_send (ANCONN, void *, int, int);
	int an_set_authscheme (ANCONN, unsigned int);
	int an_set_blocking (ANCONN, unsigned short);
	int an_set_credentials (ANCONN, const char *, const char *);
	int an_set_proxy (ANCONN, unsigned short, unsigned short, const char *,
					  unsigned short);
	int an_set_proxy_url (ANCONN, const char *);
	int an_socks4_accept (ANCONN, struct sockaddr *, int);
	int an_socks4_bind_tohostname (ANCONN, const char *, unsigned short);
	int an_socks4_bind_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_socks4_connect_tohostname (ANCONN, const char *, unsigned short);
	int an_socks4_connect_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_socks4_close (ANCONN);
	int an_socks4_getpeername (ANCONN, struct sockaddr *, int);
	int an_socks4_getsockname (ANCONN, struct sockaddr *, int);
	int an_socks4_listen (ANCONN);
	int an_socks4_recv (ANCONN, void *, int, int);
	int an_socks4_send (ANCONN, void *, int, int);
	int an_socks5_accept (ANCONN, struct sockaddr *, int);
	int an_socks5_bind_tohostname (ANCONN, const char *, unsigned short);
	int an_socks5_bind_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_socks5_connect_tohostname (ANCONN, const char *, unsigned short);
	int an_socks5_connect_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_socks5_close (ANCONN);
	int an_socks5_getpeername (ANCONN, struct sockaddr *, int);
	int an_socks5_getsockname (ANCONN, struct sockaddr *, int);
	int an_socks5_listen (ANCONN);
	int an_socks5_recv (ANCONN, void *, int, int);
	int an_socks5_send (ANCONN, void *, int, int);
	int an_ssl_connect_tohostname (ANCONN, const char *, unsigned short);
	int an_ssl_connect_tosockaddr (ANCONN, struct sockaddr *, int);
	int an_ssl_close (ANCONN);
	int an_ssl_recv (ANCONN, void *, int, int);
	int an_ssl_send (ANCONN, void *, int, int);
	int an_unset_proxy (ANCONN);

#ifdef __cplusplus
}
#endif
#endif
