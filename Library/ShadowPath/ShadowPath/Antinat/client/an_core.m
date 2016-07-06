/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_internals.h"

#if defined (HAVE_PTHREAD_H) && defined(WRAP_GETHOSTBYNAME)
#include <pthread.h>
#endif
#ifdef HAVE_NETDB_H
#include <netdb.h>
#endif
#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif
#include "antinat.h"

#if defined(WRAP_GETHOSTBYNAME) && !defined(_WIN32_)
pthread_mutex_t gethostbyname_lock = PTHREAD_MUTEX_INITIALIZER;
#endif

int
an_set_blocking (ANCONN conn, unsigned short newblocking)
{
	if (newblocking == conn->blocking)
		return AN_ERROR_SUCCESS;
	if (newblocking) {
		conn->blocking = AN_CONN_BLOCKING;
		if (conn->connection != AN_INVALID_CONNECTION) {
#ifdef _WIN32_
			unsigned long on;
			on = 1;
			ioctlsocket (conn->connection, FIONBIO, &on);
#else
			int flags;
			flags = fcntl (conn->connection, F_GETFL);
			flags = flags | O_NONBLOCK;
			fcntl (conn->connection, F_SETFL, flags);
#endif
		}
	} else {
		conn->blocking = AN_CONN_NONBLOCKING;
		if (conn->connection != AN_INVALID_CONNECTION) {
#ifdef _WIN32_
			unsigned long off;
			off = 0;
			ioctlsocket (conn->connection, FIONBIO, &off);
#else
			int flags;
			flags = fcntl (conn->connection, F_GETFL);
			flags = flags & (~O_NONBLOCK);
			fcntl (conn->connection, F_SETFL, flags);
#endif
		}
	}
	return AN_ERROR_SUCCESS;
}

int
_an_generic_close (ANCONN conn)
{
	if (conn->connection != AN_INVALID_CONNECTION)
#ifdef _WIN32_
		closesocket (conn->connection);
#else
		close (conn->connection);
#endif
	conn->connection = (SOCKET) AN_INVALID_CONNECTION;
	conn->local.family = AN_INVALID_FAMILY;
	conn->peer.family = AN_INVALID_FAMILY;
	conn->mode = AN_MODE_NONE;
	return AN_ERROR_SUCCESS;
}


unsigned int
an_getversion ()
{
	return AN_VERSION;
}

int
_an_generic_recv_all (ANCONN conn, void *buf, size_t len)
{
	int ret;
	int remaining;
	char *localbuf;
	remaining = len;
	localbuf = (char *) buf;
	while (remaining > 0) {
		ret = recv (conn->connection, localbuf, remaining, 0);
		if (ret > 0) {
			remaining -= ret;
			localbuf += ret;
		} else {
			return AN_ERROR_NETWORK;
		}
	}
	return AN_ERROR_SUCCESS;
}

int
_an_generic_send_all (ANCONN conn, const void *buf, size_t len)
{
	int ret;
	ret = send (conn->connection, buf, len, 0);
	if ((size_t) ret == len)
		return AN_ERROR_SUCCESS;
	return AN_ERROR_NETWORK;
}

int
_an_generic_recv (ANCONN conn, void *buf, size_t len, int flags)
{
	return (recv (conn->connection, buf, len, flags));
}

int
_an_generic_send (ANCONN conn, const void *buf, size_t len, int flags)
{
	return (send (conn->connection, buf, len, flags));
}

int
_an_blocking_recv (ANCONN conn, void *buf, size_t len, int flags)
{
	unsigned short oldblocking;
	int retval;
	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);
	retval = _an_generic_recv (conn, buf, len, flags);
	an_set_blocking (conn, oldblocking);
	return retval;
}

int
_an_blocking_send (ANCONN conn, const void *buf, size_t len, int flags)
{
	unsigned short oldblocking;
	int retval;
	oldblocking = conn->blocking;
	an_set_blocking (conn, 1);
	retval = _an_generic_send (conn, buf, len, flags);
	an_set_blocking (conn, oldblocking);
	return retval;
}

char *
_an_bufalloc (char *buf, int *upto, int len, int total)
{
	int oldupto;
	oldupto = *upto;
	*upto = *upto + len;
	if (*upto >= total)
		return NULL;
	return &buf[oldupto];
}

int
an_gethostbyname (const char *hostname, PHOSTENT phe, char *buf,
				  int sizeof_buf, PHOSTENT * ret, int *thread_errno)
{
#if !defined(WRAP_GETHOSTBYNAME) && !defined(_WIN32_)
#ifdef BROKEN_GETHOSTBYNAME
	*ret = gethostbyname_r (hostname, phe, buf, sizeof_buf, thread_errno);
#else
	gethostbyname_r (hostname, phe, buf, sizeof_buf, ret, thread_errno);
#endif
	if (*ret)
		return AN_ERROR_SUCCESS;
	return AN_ERROR_NAMERESOLVE;
#else /* System only has gethostbyname.  Implement with locks. */
	PHOSTENT tmphe;
	int upto = 0;
	int retval;
	int i;
	char *tmp;
	char **tmplist;
#ifndef _WIN32_					/* Win32 uses TLS for gethostbyname */
	pthread_mutex_lock (&gethostbyname_lock);
#warning Emulating gethostbyname_r, beware on multi-threaded apps, every gethostbyname *must* use this function
#endif
	tmphe = gethostbyname (hostname);
#ifndef _WIN32_
	*thread_errno = errno;
#else
	*thread_errno = WSAGetLastError ();
#endif
	if (tmphe == NULL) {
		*ret = NULL;
		retval = AN_ERROR_NAMERESOLVE;
		goto barf;
	}
	tmp = _an_bufalloc (buf, &upto, strlen (tmphe->h_name) + 1, sizeof_buf);
	if (tmp == NULL) {
		retval = AN_ERROR_NOMEM;
		goto barf;
	}
	strcpy (tmp, tmphe->h_name);
	phe->h_name = tmp;


	for (i = 0; tmphe->h_aliases[i] != NULL; i++);
	tmp = _an_bufalloc (buf, &upto, (i + 1) * sizeof (char *), sizeof_buf);
	if (tmp == NULL) {
		retval = AN_ERROR_NOMEM;
		goto barf;
	}
	tmplist = (char **) tmp;
	for (i = 0; tmphe->h_aliases[i] != NULL; i++) {
		tmp =
			_an_bufalloc (buf, &upto, strlen (tmphe->h_aliases[i]) + 1,
						  sizeof_buf);
		if (tmp == NULL) {
			retval = AN_ERROR_NOMEM;
			goto barf;
		}
		strcpy (tmp, tmphe->h_aliases[i]);
		tmplist[i] = tmp;
	}
	tmplist[i] = NULL;
	phe->h_aliases = tmplist;

	phe->h_addrtype = tmphe->h_addrtype;
	phe->h_length = tmphe->h_length;

	for (i = 0; tmphe->h_addr_list[i] != NULL; i++);
	tmp = _an_bufalloc (buf, &upto, (i + 1) * sizeof (char *), sizeof_buf);
	if (tmp == NULL) {
		retval = AN_ERROR_NOMEM;
		goto barf;
	}
	tmplist = (char **) tmp;
	for (i = 0; tmphe->h_addr_list[i] != NULL; i++) {
		tmp = _an_bufalloc (buf, &upto, phe->h_length, sizeof_buf);
		if (tmp == NULL) {
			retval = AN_ERROR_NOMEM;
			goto barf;
		}
		memcpy (tmp, tmphe->h_addr_list[i], phe->h_length);
		tmplist[i] = tmp;
	}
	tmplist[i] = NULL;
	phe->h_addr_list = tmplist;

	/* On some platforms, this is stupid, on others, necessary. */
	phe->h_addr = phe->h_addr_list[0];

	retval = AN_ERROR_SUCCESS;
	*ret = phe;
  barf:
#ifndef _WIN32_
	pthread_mutex_unlock (&gethostbyname_lock);
#endif
	return retval;

#endif
}

int
_an_rawconnect (ANCONN conn)
{
	HOSTENT he;
	char buf[1024];
	int perrno;
	int retval;
	PHOSTENT phe;
	retval =
		an_gethostbyname (conn->proxy_hostname, &he, buf, sizeof (buf), &phe,
						  &perrno);
	if (retval != AN_ERROR_SUCCESS)
		return retval;

	conn->connection = socket (conn->proxy_pf, SOCK_STREAM, 0);
	if (conn->connection == AN_INVALID_CONNECTION)
		return AN_ERROR_NETWORK;

#ifdef WITH_IPV6
	if (phe->h_addrtype == AF_INET6) {
		SOCKADDR_IN6 sa;
		memset (&sa, 0, sizeof (sa));
		memcpy (&sa.sin6_addr.s6_addr, phe->h_addr, phe->h_length);
		sa.sin6_family = AF_INET6;
		sa.sin6_port = htons (conn->proxy_port);

		retval = connect (conn->connection, (SOCKADDR *) & sa, sizeof (sa));
	} else
#endif
	{
		SOCKADDR_IN sa;
		memset (&sa, 0, sizeof (sa));
		memcpy (&sa.sin_addr.s_addr, phe->h_addr, phe->h_length);
		sa.sin_family = phe->h_addrtype;
		sa.sin_port = htons (conn->proxy_port);
		retval = connect (conn->connection, (SOCKADDR *) & sa, sizeof (sa));
	}

	if (retval == 0)
		return AN_ERROR_SUCCESS;
	return AN_ERROR_NETWORK;
}

int
_an_generic_getline (ANCONN conn, void *buf, size_t nbuf)
{
	char szBuffer[1024];
	char *inptr;
	int len;
	int sizeremaining;
	char *ret;
	int i;
	fd_set readset;
	struct timeval timeout;
	i = 0;

	inptr = szBuffer;
	sizeremaining = sizeof (szBuffer) - 1;

	while (i < 15) {
		FD_ZERO (&readset);
		FD_SET (conn->connection, &readset);
		timeout.tv_sec = 60 * 5;
		timeout.tv_usec = 0;
		if (select (conn->connection + 1, &readset, NULL, NULL, NULL) < 1)
			return AN_ERROR_NETWORK;

		/* Peek at all the available data */
		len = _an_generic_recv (conn, inptr, sizeremaining, MSG_PEEK);
		inptr[len] = '\0';
		if (len < 1)
			return AN_ERROR_NETWORK;

		/* Find a newline */
		ret = strchr (szBuffer, '\n');
		if (ret) {
			/* If we have space in the buffer */
			if ((size_t) (ret - szBuffer) < (nbuf - 4)) {
				/* Permanently read the data from the network */
				len =
					_an_generic_recv (conn, inptr,
									  (ret - szBuffer) - (inptr - szBuffer) +
									  1, 0);
				if (len < 1)
					return AN_ERROR_NETWORK;
				inptr[len] = '\0';
				strcpy (buf, szBuffer);
				ret = strchr (buf, '\n');
				if (ret)
					ret[0] = '\0';
				ret = strchr (buf, '\r');
				if (ret)
					ret[0] = '\0';
				return AN_ERROR_SUCCESS;
			}
			return AN_ERROR_NETWORK;
		} else {
			len = _an_generic_recv (conn, inptr, len, 0);
			inptr[len] = '\0';
			inptr += len;
			sizeremaining -= len;
			i++;
		}
	}

	return AN_ERROR_NETWORK;
}

int
_an_getsockaddr (struct st_sock_info *info, SOCKADDR * sa, int sl)
{
	int reqsize;
	reqsize = 0;
	switch (info->family) {
	case AF_INET:
		reqsize = sizeof (SOCKADDR_IN);
		break;
#ifdef WITH_IPV6
	case AF_INET6:
		reqsize = sizeof (SOCKADDR_IN6);
		break;
#endif
	}
	if (reqsize == 0)
		return AN_ERROR_NOTSUPPORTED;
	if (reqsize > sl)
		return AN_ERROR_NOMEM;

	switch (info->family) {
	case AF_INET:
		{
			SOCKADDR_IN *sin;
			sin = (SOCKADDR_IN *) sa;
			memset (sin, 0, sizeof (SOCKADDR_IN));
			sin->sin_family = info->family;
			sin->sin_port = htons (info->port);
			memcpy (&sin->sin_addr.s_addr, info->address, 4);
			return AN_ERROR_SUCCESS;
		}
		break;
#ifdef WITH_IPV6
	case AF_INET6:
		{
			SOCKADDR_IN6 *sin;
			sin = (SOCKADDR_IN6 *) sa;
			memset (sin, 0, sizeof (SOCKADDR_IN6));
			sin->sin6_family = info->family;
			sin->sin6_port = htons (info->port);
			memcpy (&sin->sin6_addr.s6_addr, info->address, 16);
			return AN_ERROR_SUCCESS;
		}
		break;
#endif
	}
	/* Should not happen */
	return AN_ERROR_NETWORK;
}

int
_an_setsockaddr (struct st_sock_info *info, SOCKADDR * sa, int sl)
{
	switch (sa->sa_family) {
#ifdef WITH_IPV6
	case AF_INET6:
		info->family = AF_INET6;
		memcpy (&info->address, &((SOCKADDR_IN6 *) sa)->sin6_addr.s6_addr,
				16);
		info->port = ntohs (((SOCKADDR_IN6 *) sa)->sin6_port);
		break;
#endif
	case AF_INET:
		info->family = AF_INET;
		memcpy (&info->address, &((SOCKADDR_IN *) sa)->sin_addr.s_addr, 4);
		info->port = ntohs (((SOCKADDR_IN *) sa)->sin_port);
		break;
	default:
		return AN_ERROR_NOTSUPPORTED;
	}
	return AN_ERROR_SUCCESS;
}

int
_an_setsockaddr_sock (struct st_sock_info *info, SOCKET s, int peer)
{
	PI_SA sa;
	sl_t sl;
	int ret;
	sl = sizeof (sa);
	if (peer) {
		ret = getpeername (s, (SOCKADDR *) & sa, &sl);
	} else {
		ret = getsockname (s, (SOCKADDR *) & sa, &sl);
	}
	if (ret == 0) {
		return _an_setsockaddr (info, (SOCKADDR *) & sa, sl);
	}
	return AN_ERROR_NETWORK;
}

char *
an_geterror (int error)
{
	switch (error) {
	case AN_ERROR_SUCCESS:
		return "The operation completed successfully.";
		break;
	case AN_ERROR_NOTSUPPORTED:
		return "The operation is not supported or not currently supported.";
		break;
	case AN_ERROR_INVALIDARG:
		return "An argument was invalid.";
		break;
	case AN_ERROR_NOMEM:
		return "There was insufficient memory to complete this operation.";
		break;
	case AN_ERROR_NETWORK:
		return "A network error occurred.";
		break;
	case AN_ERROR_PROXY:
		return "A proxy error occurred.";
		break;
	case AN_ERROR_AUTH:
		return "The credentials supplied were incorrect.";
		break;
	case AN_ERROR_ORDER:
		return "A command sequence was attempted that was invalid.";
		break;
	}
	return NULL;
}

int
AN_FD_SET (ANCONN s, fd_set * set, int top)
{
	FD_SET (s->connection, set);
	if ((int) s->connection > top)
		return s->connection;
	return top;
}

int
AN_FD_ISSET (ANCONN s, fd_set * set)
{
	return FD_ISSET (s->connection, set);
}

void
AN_FD_CLR (ANCONN s, fd_set * set)
{
	FD_CLR (s->connection, set);
}
