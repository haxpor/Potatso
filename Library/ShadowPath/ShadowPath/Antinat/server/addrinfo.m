/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-04 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif

#ifdef WITH_IPV6
static BOOL
ipv6_fromsockaddr (addrinfo_t * dest, SOCKADDR_IN6 * sin)
{
	ai_setAddress_str (dest, (char *) &sin->sin6_addr.s6_addr, 16);
	dest->port = sin->sin6_port;
	dest->address_type = AF_INET6;
	return TRUE;
}

static BOOL
ipv6_tosockaddr (addrinfo_t * src, SOCKADDR_IN6 ** ret, sl_t * len)
{
	SOCKADDR_IN6 *sin;
	sin = (SOCKADDR_IN6 *) malloc (sizeof (SOCKADDR_IN6));
	if (sin == NULL)
		return FALSE;
	memset (sin, 0, sizeof (SOCKADDR_IN6));
	sin->sin6_family = src->address_type;
	sin->sin6_port = src->port;
	memcpy (sin->sin6_addr.s6_addr, src->address, 16);
	*ret = sin;
	*len = sizeof (SOCKADDR_IN6);
	return TRUE;
}

static char *
ipv6_getaddrstring (addrinfo_t * src)
{
	char *str;
	char addr[18];
	int i;
	memcpy (addr, src->address, 16);
	str = (char *) malloc (80);
	if (str != NULL) {
		char szTemp[6];
		strcpy (str, "");
		for (i = 0; i < 16; i++) {
			if (i > 0)
				strcat (str, ":");
			sprintf (szTemp, "%x", addr[i]);
			strcat (str, szTemp);
		}
	}
	return str;
}

static char *
ipv6_getstring (addrinfo_t * src)
{
	char *str;
	unsigned short port;
	char tmp[10];
	str = ipv6_getaddrstring (src);
	if (str != NULL) {
		port = src->port;
		port = ntohs (port);
		sprintf (tmp, "%i", port);
		strcat (str, ":");
		strcat (str, tmp);
	}
	return str;
}
#endif

static BOOL
ipv4_fromsockaddr (addrinfo_t * dest, SOCKADDR_IN * sin)
{
	ai_setAddress_str (dest, (char *) &sin->sin_addr.s_addr, 4);
	dest->port = sin->sin_port;
	dest->address_type = AF_INET;
	return TRUE;
}

static BOOL
ipv4_tosockaddr (addrinfo_t * src, SOCKADDR_IN ** ret, sl_t * len)
{
	SOCKADDR_IN *sin;
	sin = (SOCKADDR_IN *) malloc (sizeof (SOCKADDR_IN));
	if (sin == NULL)
		return FALSE;
	memset (sin, 0, sizeof (SOCKADDR_IN));
	sin->sin_family = src->address_type;
	sin->sin_port = src->port;
	memcpy (&sin->sin_addr.s_addr, src->address, 4);
	*ret = sin;
	*len = sizeof (SOCKADDR_IN);
	return TRUE;
}

static char *
ipv4_getaddrstring (addrinfo_t * src)
{
	char *str;
	unsigned long addr;
	memcpy (&addr, src->address, 4);
	addr = ntohl (addr);
	str = (char *) malloc (25);
	if (str != NULL) {
		sprintf (str, "%lu.%lu.%lu.%lu",
				 addr / 0x01000000,
				 (addr & 0xffffff) / 0x010000,
				 (addr & 0xffff) / 0x0100, (addr & 0xff));
	}
	return str;
}

static char *
ipv4_getstring (addrinfo_t * src)
{
	char *str;
	unsigned short port;
	char tmp[10];
	str = ipv4_getaddrstring (src);
	if (str != NULL) {
		port = src->port;
		port = ntohs (port);
		sprintf (tmp, "%i", port);
		strcat (str, ":");
		strcat (str, tmp);
	}
	return str;
}

void
ai_init (addrinfo_t * ai, SOCKADDR * sa)
{
	ai->nulladdr = TRUE;
	ai->address_type = 0;
	ai->address = NULL;
	ai->port = 0;
	ai->addrlen = 0;
	ai_setAddress_sa (ai, sa);
}


void
ai_close (addrinfo_t * ai)
{
	if (ai->address)
		free (ai->address);
}

char *
ai_getString (addrinfo_t * ai)
{
	switch (ai->address_type) {
	case AF_INET:
		return ipv4_getstring (ai);
		break;
#ifdef WITH_IPV6
	case AF_INET6:
		return ipv6_getstring (ai);
		break;
#endif
	}
	return NULL;
}

char *
ai_getAddressString (addrinfo_t * ai)
{
	switch (ai->address_type) {
	case AF_INET:
		return ipv4_getaddrstring (ai);
		break;
#ifdef WITH_IPV6
	case AF_INET6:
		return ipv6_getaddrstring (ai);
		break;
#endif
	}
	return NULL;
}

BOOL
ai_getSockaddr (addrinfo_t * ai, SOCKADDR ** sa, sl_t * len)
{
	switch (ai->address_type) {
	case AF_INET:
		return ipv4_tosockaddr (ai, (SOCKADDR_IN **) sa, len);
		break;
#ifdef WITH_IPV6
	case AF_INET6:
		return ipv6_tosockaddr (ai, (SOCKADDR_IN6 **) sa, len);
		break;
#endif
	}
	return FALSE;
}

BOOL
ai_setAddress_sa (addrinfo_t * ai, SOCKADDR * sa)
{
	if (sa) {
		switch (sa->sa_family) {
		case AF_INET:
			return ipv4_fromsockaddr (ai, (SOCKADDR_IN *) sa);
			break;
#ifdef WITH_IPV6
		case AF_INET6:
			return ipv6_fromsockaddr (ai, (SOCKADDR_IN6 *) sa);
			break;
#endif
		}
	} else {
		ai->address_type = 0;
	}
	return FALSE;
}

BOOL
ai_setAddress_str (addrinfo_t * ai, char *newaddr, int newlen)
{
	int i;
	if (ai->address)
		free (ai->address);
	ai->address = (char *) malloc (newlen);
	if (ai->address == NULL)
		return FALSE;
	memcpy (ai->address, newaddr, newlen);
	ai->addrlen = newlen;
	ai->nulladdr = FALSE;
	for (i = 0; (ai->address[i] == 0) && (i < newlen); i++);
	if (i >= newlen)
		ai->nulladdr = TRUE;
	return TRUE;
}
