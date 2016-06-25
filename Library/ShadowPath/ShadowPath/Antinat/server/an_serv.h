/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#ifndef an_serv_h
#define an_serv_h

#define _REENTRANT
#ifdef WIN32_NO_CONFIG_H
#ifndef _WIN32_
#define _WIN32_
#endif
#include "winconf.h"
#else
#include "an_config.h"
#endif

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#ifdef HAVE_PTHREAD_H
#include <pthread.h>
#endif
#ifdef HAVE_TIME_H
#include <time.h>
#else
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#endif
#include <Foundation/Foundation.h>

//typedef int BOOL;

#ifndef HAVE_TRUEFALSE
#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE (!FALSE)
#endif
#endif

#if ( __GNUC__ == 3 && __GNUC_MINOR__ > 0 ) || __GNUC__ > 3
#define DEPRECATED    __attribute__((deprecated))
#else
#define DEPRECATED
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>



#ifdef _WIN32_
#define WIN32_LEAN_AND_MEAN
#include <winsock.h>
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#endif

#include "antinat.h"


#ifndef _WIN32_
typedef struct hostent HOSTENT;
typedef struct sockaddr SOCKADDR;
typedef struct sockaddr_in SOCKADDR_IN;
typedef int SOCKET;
#define INVALID_SOCKET -1


static NSMutableDictionary *conn_dict;

#define closesocket(x) close(x)
#endif /* !_WIN32_ */

#ifdef _WIN32_
#define sleep(x) Sleep(x*1000)
#endif /* _WIN32_ */

typedef enum { B_NO, B_YES, NOTYET } BOOLX;

#ifndef __FILE__
#define __FILE__ ""
#endif


/*
 * Set up filter defines
 */
enum {
	FILTER_DEFAULT = 0,
	FILTER_ALLOW = 1,
	FILTER_DENY = 2
};

enum {
	TYPE_SOURCE = 1,
	TYPE_DEST = 2
};

/*
 * Set up log defines
 */
enum {
	LOG_TYPE_CONNECTIONESTABLISHED = 1,
	LOG_TYPE_CONNECTIONCLOSE = 2
};

enum {
	LOG_EVT_LOG = 0,
	LOG_EVT_SERVERSTART = 1,
	LOG_EVT_SERVERCLOSE = 2,
	LOG_EVT_SERVERRESTART = 3
};

enum {
	LOG_MONTH = 0,
	LOG_DAY = 1,
	LOG_HOUR = 2,
	LOG_MINUTE = 3
};

enum {
	AUTH_ANON = 0,
	AUTH_LOCAL = 1,
	AUTH_CONFIG = 2
};

#define LOG_MAX 4				/* Array size */

#ifdef WITH_IPV6
typedef struct sockaddr_in6 SOCKADDR_IN6;
typedef SOCKADDR_IN6 PI_SA;
#else
typedef SOCKADDR_IN PI_SA;
#endif

typedef struct addrinfo_t {
	int address_type;
	unsigned int port;
	int addrlen;
	BOOL nulladdr;
	char *address;
} addrinfo_t;

typedef struct os_thread_t {
#ifndef _WIN32_
	pthread_t tid;
#else
	HANDLE hThread;
	DWORD tid;
#endif
} os_thread_t;

typedef struct os_mutex_t {
#ifndef _WIN32_
	pthread_mutex_t mutex;
#else
	HANDLE mutex;
#endif
} os_mutex_t;

typedef struct DSListElement {
	int flags;
	union {
		unsigned int nKey;
		char *strKey;
	} k;
	union {
		unsigned int nData;
		void *pData;
	} d;
	struct DSListElement *next;
} DSListElement;

extern enum {
	CLEANUP_KEY_FREE = 1,
	CLEANUP_VALUE_FREE = 2,
	CLEANUP_ALL = 3
} cf;

typedef struct DSList {
	DSListElement *head;
	DSListElement *tail;
	unsigned int numElements;
} DSList;

void ds_list_init (DSList *);
void ds_list_close (DSList *);
BOOL ds_list_sortAsString (DSList *);

typedef struct DSHashTable {
	unsigned int buckets;
	DSList **bucket;
	unsigned int primeA;
	unsigned int primeB;

} DSHashTable;

#define DEF_PRIMEA 89258459
#define DEF_PRIMEB 252584539

void ds_hash_close (DSHashTable *);
DSList *ds_hash_getList (DSHashTable *);
void ds_hash_init (DSHashTable *, unsigned int, unsigned int, unsigned int);
unsigned int ds_hash_getNumericValue_n (DSHashTable *, unsigned int Key);
void *ds_hash_getPtrValue_s (DSHashTable *, const char *Key);
void *ds_hash_getPtrValue_n (DSHashTable *, unsigned int Key);
void ds_hash_insert_ss (DSHashTable *, char *Key, void *Data, int);

typedef struct DSTSHashTable {
	os_mutex_t lock;
	DSHashTable hsh;
} DSTSHashTable;

typedef struct DSParams {
	unsigned int lsmask;
	unsigned int lfmask;
	DSHashTable hsh;
} DSParams;
void ds_param_init (DSParams *);
void ds_param_close (DSParams *);
BOOL ds_param_setFlagSwitch (DSParams *, unsigned char c);
BOOL ds_param_setStringSwitch (DSParams *, unsigned char c);
BOOL ds_param_process_argv (DSParams *, int argc, char *argv[]);
BOOL ds_param_process_str (DSParams *, char *arg);



enum {
	AUTHCHOICE_ACT_BRANCH = 1,
	AUTHCHOICE_ACT_SELECT = 2
};

enum {
	FILTER_ACT_BRANCH = 1,
	FILTER_ACT_ACCEPT = 2,
	FILTER_ACT_REJECT = 3,
	FILTER_ACT_CHAIN = 4
};

typedef struct ac_nodes {
	int action;
	union {
		struct authchoice *branch;
		unsigned char select;
	} alt;
} ac_nodes;

typedef struct chain_t {
	char *name;
	char *uri;
	char *user;
	char *pass;
	unsigned int authschemes;
	struct chain_t *next;
} chain_t;

typedef struct fil_nodes {
	int action;
	union {
		struct filter *branch;
		struct chain_t *chain;
	} alt;
} fil_nodes;

typedef struct authchoice {
	unsigned int source_port;
	int source_addrtype;
	unsigned char *source_addr;

	int have_source_port:1;
	int have_source_addrtype:1;
	int have_source_addrtype_inherited:1;
	int have_source_addr:1;

	ac_nodes *nodes;
	int nnodes;
} authchoice_t;

typedef struct filter {
	unsigned int source_port;
	int source_addrtype;
	unsigned char *source_addr;

	unsigned int dest_port;
	int dest_addrtype;
	unsigned char *dest_addr;

	int version;
	char *user;
	int authscheme;
	int authsrc;
	int socksop;

	int throttle;

	int have_source_port:1;
	int have_source_addrtype:1;
	int have_source_addrtype_inherited:1;
	int have_source_addr:1;
	int have_dest_port:1;
	int have_dest_addrtype:1;
	int have_dest_addrtype_inherited:1;
	int have_dest_addr:1;
	int have_version:1;
	int have_user:1;
	int have_authscheme:1;
	int have_authsrc:1;
	int have_socksop:1;

	int have_throttle:1;

	fil_nodes *nodes;
	int nnodes;
} filter_t;

typedef struct summarylog {
	char *useAddrFile[LOG_MAX];
	char *useUserFile[LOG_MAX];
	char *useConnFile;
} summarylog_t;

typedef struct config {
	authchoice_t *auth;
	chain_t *chains;
	filter_t *filt;
	summarylog_t sumlog;
	unsigned int intface;
	int maxbindwait;
	int port;
	int throttle;
	int maxconnsperthread;
	int usecount;
	int allowlocalusers;

	int refcount;
	os_mutex_t lock;

	DSHashTable *users;
} config_t;

typedef struct conn_t {
	int version;
	int authscheme;
	int authsrc;
	int socksop;
	int throttle;

	unsigned long nExternalSendBytes;
	unsigned long nExternalRecvBytes;

	time_t startTime;

	char *user;
	char *pass;

	config_t *conf;

	addrinfo_t source;
	addrinfo_t dest;
	addrinfo_t source_on_server;

	char *buffer;				/* A pointer to where to read/write */
	int bufflen;				/* How big is that buffer in the window ... */
	int buff_upto;				/* Where are we up to in it */

	SOCKET s;
} conn_t;

BOOL conn_forwardData (conn_t *, ANCONN);
void conn_setUser (conn_t *, char *);
void conn_setPass (conn_t *, char *);
BOOL conn_setDestHostname (conn_t *, char *);
BOOL conn_getSlab (conn_t *, char *, int);
BOOL conn_sendData (conn_t *, const char *, int);
BOOL conn_getChar (conn_t *, unsigned char *);
void conn_close (conn_t *);
BOOL conn_setupchain (conn_t *, ANCONN, chain_t *);

/* This constructor associates with a socket for TCP connections */
void conn_init_tcp (conn_t *, config_t *, SOCKET);

/* This constructor associates with a UDP packet */
void conn_init_udp (conn_t *, config_t *, SOCKADDR * sa, char *, int);

/* Functions to manipulate address structures*/
void ai_init (addrinfo_t *, SOCKADDR *);
void ai_close (addrinfo_t *);

char *ai_getString (addrinfo_t *);
char *ai_getAddressString (addrinfo_t *);

BOOL ai_getSockaddr (addrinfo_t *, SOCKADDR **, sl_t *);

BOOL ai_setAddress_sa (addrinfo_t *, SOCKADDR *);
BOOL ai_setAddress_str (addrinfo_t *, char *, int);

/* Function called as soon as a new thread is created */
void *ChildThread (void *param);

/* Functions to perform authentication negotiation */
BOOL auth_unpw (conn_t * conn);
BOOL auth_chap (conn_t * conn);

/* Functions to access configuration information */
BOOL loadconfig (config_t * conf, const char *config_content, int config_content_size);
unsigned char config_choosemethod (config_t * conf, conn_t * conn,
								   unsigned char *meths, int nmeths);

int config_getMaxbindwait (config_t * conf);
int config_getPort (config_t * conf);
int config_getMaxConnsPerThread (config_t * conf);
unsigned int config_getInterface (config_t * conf);
char *config_getAddrLog (config_t * conf, int index);
char *config_getUserLog (config_t * conf, int index);
char *config_getConnLog (config_t * conf);
BOOL config_isallowed (config_t * conf, conn_t * conn, chain_t ** chain);
char *config_getUser (config_t * conf, const char *user);
void config_free (config_t * conf);
BOOL config_allowLocalUsers (config_t * conf);

void config_reference (config_t * conf);
void config_dereference (config_t * conf);

/* Functions to perform logging */
BOOL log_log (conn_t * conn, int event, int subtype, config_t * conf);

/*
 * Set up global locks and variables
 */
extern os_mutex_t crypt_lock;
extern os_mutex_t getpwnam_lock;
extern os_mutex_t getspnam_lock;
extern os_mutex_t localtime_lock;
extern os_mutex_t writerpipe_lock;

BOOL socks5_handler (conn_t * conn);
BOOL socks4_handler (conn_t * conn);
BOOL socks5_init_module ();

void os_thread_init (os_thread_t * thr);
void os_thread_close (os_thread_t * thr);
void os_thread_detach (os_thread_t * thr);
int os_thread_exec (os_thread_t * thr, void *(*start) (void *), void *arg);
void os_mutex_init (os_mutex_t * lock);
void os_mutex_close (os_mutex_t * lock);
void os_mutex_lock (os_mutex_t * lock);
void os_mutex_unlock (os_mutex_t * lock);
int os_pipe (int *ends);
void os_debug_log (const char *filename, const char *msg);

#ifdef WITH_DEBUG
#define DEBUG_LOG(x) os_debug_log(__FILE__,x);
#endif


#endif
