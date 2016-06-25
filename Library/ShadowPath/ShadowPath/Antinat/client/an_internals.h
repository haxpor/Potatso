/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#ifndef _AN_INTERNALS_H
#define _AN_INTERNALS_H

#define __AN_KERNEL
#define _GNU_SOURCE
#define _REENTRANT

#ifdef WIN32_NO_CONFIG_H
#define _WIN32_
#endif

#ifndef _WIN32_
#include "an_config.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#else
#include "../winconf.h"
#define WIN32_LEAN_AND_MEAN
#include <winsock.h>
#endif

#ifndef _WIN32_
typedef struct sockaddr_in SOCKADDR_IN;
typedef struct sockaddr SOCKADDR;
typedef struct hostent HOSTENT;
typedef HOSTENT *PHOSTENT;
#endif

#ifdef WITH_IPV6
typedef struct sockaddr_in6 SOCKADDR_IN6;
typedef SOCKADDR_IN6 PI_SA;
#else
typedef SOCKADDR_IN PI_SA;
#endif

#if !(defined(HAVE_GETHOSTBYNAME_R)||defined(HAVE_NSL_GETHOSTBYNAME_R)||defined(_WIN32_))
#define WRAP_GETHOSTBYNAME 1
#else
#undef WRAP_GETHOSTBYNAME
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif
#ifdef HAVE_SELECT_H
#include <select.h>
#endif
#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#define AN_AUTH_UNDEF 0x80000000
#define AN_AUTH_MAX   3


#endif
