/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-04 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#ifdef HAVE_TIME_H
#include <time.h>
#endif

int lastlog[LOG_MAX];

typedef DSTSHashTable *PDSTSHT;

PDSTSHT logAddr[LOG_MAX];
PDSTSHT logUser[LOG_MAX];

char *logAddrFilename[LOG_MAX];
char *logUserFilename[LOG_MAX];

/* Connection logging */
FILE *an_logfile = NULL;

BOOL locksinit = FALSE;
os_mutex_t lastlog_lock;
os_mutex_t connection_filelock;

typedef struct stLogInfo {
	unsigned long uploadBytes;
	unsigned long downloadBytes;
} stLogInfo;

typedef struct stLogPath {
	DSTSHashTable *src;
	char path[256];
} stLogPath;

static void *
log_outputLogChildThread (void *pdata)
{
	DSList *lst;
	DSListElement *le;
	stLogInfo *li;
	struct stLogPath *param;
	FILE *fp;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	param = (struct stLogPath *) pdata;
	os_mutex_lock (&param->src->lock);
#ifdef WITH_DEBUG
	sprintf (szDebug, "Attempting to update summary log %s", param->path);
	DEBUG_LOG (szDebug);
#endif
	fp = fopen (param->path, "a");
	if (fp) {
		fprintf (fp, "\n");
		lst = ds_hash_getList (&param->src->hsh);
		ds_list_sortAsString (lst);
		for (le = lst->head; le != NULL; le = le->next) {
			li = (stLogInfo *) le->d.pData;
			fprintf (fp, "%s %lu %lu\n", le->k.strKey,
					 li->downloadBytes, li->uploadBytes);
		}
		ds_list_close (lst);
		free (lst);
		fclose (fp);
	}
	ds_hash_close (&param->src->hsh);
	os_mutex_unlock (&param->src->lock);
	os_mutex_close (&param->src->lock);
	free (param->src);
	free (param);
	return NULL;
}



static BOOL
log_outputLog (DSTSHashTable ** src, char *path)
{
	struct stLogPath *logpath;
	os_thread_t thr;
	os_thread_init (&thr);
	logpath = (struct stLogPath *) malloc (sizeof (stLogPath));
	logpath->src = *src;
	strncpy (logpath->path, path, sizeof (logpath->path));
	*src = (DSTSHashTable *) malloc (sizeof (DSTSHashTable));
	ds_hash_init (&(*src)->hsh, 100, DEF_PRIMEA, DEF_PRIMEB);
	os_mutex_init (&(*src)->lock);
	os_thread_exec (&thr, log_outputLogChildThread, logpath);
	os_thread_detach (&thr);
	return TRUE;
}

static BOOL
log_updatelast (struct tm *tm)
{
	lastlog[LOG_MONTH] = tm->tm_mon;
	lastlog[LOG_DAY] = tm->tm_mday;
	lastlog[LOG_HOUR] = tm->tm_hour;
	lastlog[LOG_MINUTE] = tm->tm_min;
	return TRUE;
}

static BOOL
log_checkForLogOutput ()
{
	BOOL changed[LOG_MAX];
	int i;
	time_t now;
	struct tm *tm;
#ifdef HAVE_LOCALTIME_R
	struct tm realtm;
#endif

#ifdef WITH_DEBUG
	DEBUG_LOG ("Attempting to find if log output necessary");
#endif

	for (i = 0; i < LOG_MAX; i++)
		changed[i] = FALSE;

	time (&now);

	os_mutex_lock (&lastlog_lock);
#ifdef HAVE_LOCALTIME_R
	tm = localtime_r (&now, &realtm);
#else
	os_mutex_lock (&localtime_lock);
	tm = localtime (&now);
#endif
	/* FIXME: Year checking? */
	if (tm->tm_mon != lastlog[LOG_MONTH])
		changed[LOG_MONTH] = TRUE;
	if ((tm->tm_mday != lastlog[LOG_DAY]) || (changed[LOG_MONTH]))
		changed[LOG_DAY] = TRUE;
	if ((tm->tm_hour != lastlog[LOG_HOUR]) || (changed[LOG_DAY]))
		changed[LOG_HOUR] = TRUE;
	if ((tm->tm_min != lastlog[LOG_MINUTE]) || (changed[LOG_HOUR]))
		changed[LOG_MINUTE] = TRUE;
	log_updatelast (tm);

#ifndef HAVE_LOCALTIME_R
	os_mutex_unlock (&localtime_lock);
#endif

	for (i = 0; i < LOG_MAX; i++) {
		if (changed[i]) {
			if (logAddrFilename[i])
				log_outputLog (&logAddr[i], logAddrFilename[i]);
			if (logUserFilename[i])
				log_outputLog (&logUser[i], logUserFilename[i]);
		}
	}
	os_mutex_unlock (&lastlog_lock);
	return TRUE;
}

static BOOL
log_summ_single (DSTSHashTable * dest, char *key, unsigned long down,
				 unsigned long up)
{
	stLogInfo *li;
	os_mutex_lock (&dest->lock);
	li = (stLogInfo *) ds_hash_getPtrValue_s (&dest->hsh, key);
	if (li) {
		li->uploadBytes += up;
		li->downloadBytes += down;
	} else {
		char *keycopy;
		li = (stLogInfo *) malloc (sizeof (stLogInfo));
		keycopy = (char *) malloc (strlen (key) + 1);
		strcpy (keycopy, key);
		li->uploadBytes = up;
		li->downloadBytes = down;
		ds_hash_insert_ss (&dest->hsh, keycopy, li, CLEANUP_KEY_FREE |
						   CLEANUP_VALUE_FREE);
	}

	os_mutex_unlock (&dest->lock);
	return TRUE;
}

static BOOL
log_summary_real (conn_t * conn)
{
	unsigned long upload;
	unsigned long download;
	char *logkey;
	int i;

	log_checkForLogOutput ();

	upload = conn->nExternalSendBytes;
	download = conn->nExternalRecvBytes;
	logkey = ai_getAddressString (&conn->source);

	for (i = 0; i < LOG_MAX; i++) {
		if (logAddrFilename[i])
			log_summ_single (logAddr[i], logkey, download, upload);
	}

	free (logkey);

	logkey = conn->user;
	if (logkey == NULL)
		logkey = "Anonymous";

	for (i = 0; i < LOG_MAX; i++) {
		if (logUserFilename[i])
			log_summ_single (logUser[i], logkey, download, upload);
	}

	return TRUE;
}

static BOOL
log_summary (conn_t * conn, int event, config_t * conf)
{
	time_t now;
	int i;
	struct tm *tm;
#ifdef HAVE_LOCALTIME_R
	struct tm realtm;
#endif
	switch (event) {
	case LOG_EVT_SERVERSTART:
		if (locksinit == FALSE)
			os_mutex_init (&lastlog_lock);
		for (i = 0; i < LOG_MAX; i++) {
			if (config_getAddrLog (conf, i)) {
				logAddrFilename[i] =
					(char *) malloc (strlen (config_getAddrLog (conf, i)) +
									 1);
				strcpy (logAddrFilename[i], config_getAddrLog (conf, i));
				logAddr[i] =
					(DSTSHashTable *) malloc (sizeof (DSTSHashTable));
				ds_hash_init (&logAddr[i]->hsh, 100, DEF_PRIMEA, DEF_PRIMEB);
				os_mutex_init (&logAddr[i]->lock);
			} else {
				logAddrFilename[i] = NULL;
				logAddr[i] = NULL;
			}
			if (config_getUserLog (conf, i)) {
				logUserFilename[i] =
					(char *) malloc (strlen (config_getUserLog (conf, i)) +
									 1);
				strcpy (logUserFilename[i], config_getUserLog (conf, i));
				logUser[i] =
					(DSTSHashTable *) malloc (sizeof (DSTSHashTable));
				ds_hash_init (&logUser[i]->hsh, 100, DEF_PRIMEA, DEF_PRIMEB);
				os_mutex_init (&logUser[i]->lock);
			} else {
				logUserFilename[i] = NULL;
				logUser[i] = NULL;
			}
		}

		time (&now);
		os_mutex_lock (&lastlog_lock);
#ifndef HAVE_LOCALTIME_R
		os_mutex_lock (&localtime_lock);
		tm = localtime (&now);
#else
		tm = localtime_r (&now, &realtm);
#endif
		log_updatelast (tm);
#ifndef HAVE_LOCALTIME_R
		os_mutex_unlock (&localtime_lock);
#endif
		os_mutex_unlock (&lastlog_lock);
		break;
	case LOG_EVT_SERVERCLOSE:
		now = (time_t) 0;
		os_mutex_lock (&lastlog_lock);
#ifndef HAVE_LOCALTIME_R
		os_mutex_lock (&localtime_lock);
		tm = localtime (&now);
#else
		tm = localtime_r (&now, &realtm);
#endif
		log_updatelast (tm);
#ifndef HAVE_LOCALTIME_R
		os_mutex_unlock (&localtime_lock);
#endif
		os_mutex_unlock (&lastlog_lock);
		log_checkForLogOutput ();
		for (i = 0; i < LOG_MAX; i++) {
			if (logAddr[i]) {
				ds_hash_close (&logAddr[i]->hsh);
				os_mutex_close (&logAddr[i]->lock);
				free (logAddr[i]);
			}
			if (logUser[i]) {
				ds_hash_close (&logUser[i]->hsh);
				os_mutex_close (&logUser[i]->lock);
				free (logUser[i]);
			}
			if (logAddrFilename[i]) {
				free (logAddrFilename[i]);
				logAddrFilename[i] = NULL;
			}
			if (logUserFilename[i]) {
				free (logUserFilename[i]);
				logUserFilename[i] = NULL;
			}
		}

		break;
	case LOG_EVT_LOG:
		return log_summary_real (conn);
		break;
	}
	return TRUE;
}

static BOOL
connection_real_log (conn_t * conn)
{
	char *strSourceAddr;
	char *strDestAddr;
	char *strUser;
	time_t now;
	char strTime[100];
#ifdef HAVE_LOCALTIME_R
	struct tm realtm;
#endif
	struct tm *tm;
	time (&now);

#ifdef HAVE_LOCALTIME_R
	tm = localtime_r (&now, &realtm);
#else
	os_mutex_lock (&localtime_lock);
	tm = localtime (&now);
#endif
	strftime (strTime, sizeof (strTime), "%a, %d %b %Y %H:%M:%S", tm);
#ifndef HAVE_LOCALTIME_R
	os_mutex_unlock (&localtime_lock);
#endif

	os_mutex_lock (&connection_filelock);
	if (an_logfile) {
		strSourceAddr = ai_getString (&conn->source);
		strDestAddr = ai_getString (&conn->dest);
		strUser = conn->user;

		if (strUser) {
			fprintf (an_logfile, "%s %s %s %s\n", strTime,
					 strSourceAddr, strDestAddr, strUser);
		} else {
			fprintf (an_logfile, "%s %s %s\n", strTime,
					 strSourceAddr, strDestAddr);
		}
		os_mutex_unlock (&connection_filelock);

		free (strSourceAddr);
		free (strDestAddr);
		return TRUE;
	} else {
		os_mutex_unlock (&connection_filelock);
		return FALSE;
	}
}

static BOOL
log_connection (conn_t * conn, int event, config_t * conf)
{
	switch (event) {
	case LOG_EVT_SERVERSTART:
		if (locksinit == FALSE)
			os_mutex_init (&connection_filelock);
		if (config_getConnLog (conf)) {
			os_mutex_lock (&connection_filelock);
			an_logfile = fopen (config_getConnLog (conf), "a");
			os_mutex_unlock (&connection_filelock);
		} else {
			an_logfile = NULL;
		}
		break;
	case LOG_EVT_SERVERCLOSE:
		if (an_logfile) {
			os_mutex_lock (&connection_filelock);
			fclose (an_logfile);
			an_logfile = NULL;
			os_mutex_unlock (&connection_filelock);
		}
		break;
	case LOG_EVT_SERVERRESTART:
		log_connection (conn, LOG_EVT_SERVERCLOSE, conf);
		log_connection (conn, LOG_EVT_SERVERSTART, conf);
		break;
	case LOG_EVT_LOG:
		if (an_logfile)
			return connection_real_log (conn);
		break;
	}
	return TRUE;
}

BOOL
log_log (conn_t * conn, int event, int subtype, config_t * conf)
{
	switch (event) {
	case LOG_EVT_LOG:
		switch (subtype) {
		case LOG_TYPE_CONNECTIONESTABLISHED:
			return log_connection (conn, event, conn->conf);
			break;
		case LOG_TYPE_CONNECTIONCLOSE:
			return log_summary (conn, event, conn->conf);
			break;
		}
		break;
	default:
		log_connection (conn, event, conf);
		log_summary (conn, event, conf);
		break;
	}
	return TRUE;
}
