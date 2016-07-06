/* LIBDS
 * =====
 * This software is Copyright (c) 2002-04 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */
#include "an_serv.h"
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif

static void
ds_le_init (DSListElement * le)
{
	le->flags = 0;
	le->d.nData = 0;
	le->d.pData = NULL;
	le->k.nKey = 0;
	le->k.strKey = NULL;
	le->next = NULL;
}

static void
ds_le_copy (DSListElement * le, DSListElement * src)
{
	le->flags = src->flags;
	le->d.nData = src->d.nData;
	le->d.pData = src->d.pData;
	le->k.nKey = src->k.nKey;
	le->k.strKey = src->k.strKey;
	le->next = src->next;
}


static void
ds_le_close (DSListElement * le)
{
	if ((le->flags & CLEANUP_VALUE_FREE) && le->d.pData) {
		free (le->d.pData);
	}
	if ((le->flags & CLEANUP_KEY_FREE) && le->k.strKey) {
		free (le->k.strKey);
	}
}

#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif

void
ds_list_init (DSList * lst)
{
	lst->head = NULL;
	lst->tail = NULL;
	lst->numElements = 0;
}

void
ds_list_close (DSList * lst)
{
	DSListElement *current, *next;
	current = lst->head;
	lst->head = NULL;
	lst->tail = NULL;
	while (current != NULL) {
		next = current->next;
		ds_le_close (current);
		free (current);
		current = next;
	}
	lst->numElements = 0;
}

static void
ds_list_setHead (DSList * list, DSListElement * newHead)
{
	if (list->head == NULL)
		list->tail = newHead;
	list->head = newHead;
}

static DSListElement *
ds_list_getElement_n (DSList * list, unsigned int Key)
{
	DSListElement *node;
	for (node = list->head; node != NULL; node = node->next) {
		if (node->k.nKey == Key)
			return node;
	}
	return (NULL);
}

static DSListElement *
ds_list_getElement_s (DSList * list, const char *Key)
{
	DSListElement *node;
	for (node = list->head; node != NULL; node = node->next) {
		if (!strcmp (node->k.strKey, Key))
			return node;
	}
	return (NULL);
}

static void *
ds_list_getPtrValue_s (DSList * list, const char *Key)
{
	DSListElement *node;
	node = ds_list_getElement_s (list, Key);
	if (node)
		return node->d.pData;
	return (NULL);
}

static void *
ds_list_getPtrValue_n (DSList * list, unsigned int Key)
{
	DSListElement *node;
	node = ds_list_getElement_n (list, Key);
	if (node)
		return node->d.pData;
	return (NULL);
}

static unsigned int
ds_list_getNumericValue_n (DSList * list, unsigned int Key)
{
	DSListElement *node;
	node = ds_list_getElement_n (list, Key);
	if (node)
		return node->d.nData;
	return (0);
}


static void
ds_list_insert (DSList * list, DSListElement * node)
{
	node->next = list->head;
	ds_list_setHead (list, node);
	list->numElements++;
}

static void
ds_list_insert_ss (DSList * list, char *key, void *value, int cleanup)
{
	DSListElement *node;
	node = (DSListElement *) malloc (sizeof (DSListElement));
	ds_le_init (node);
	node->k.strKey = key;
	node->d.pData = value;
	node->next = list->head;
	node->flags = cleanup;
	ds_list_setHead (list, node);
	list->numElements++;
}

static void
ds_list_insert_ns (DSList * list, unsigned int key, void *value, int cleanup)
{
	DSListElement *node;
	node = (DSListElement *) malloc (sizeof (DSListElement));
	ds_le_init (node);
	node->k.nKey = key;
	node->d.pData = value;
	node->next = list->head;
	node->flags = cleanup;
	ds_list_setHead (list, node);
	list->numElements++;
}

static void
ds_list_insert_sn (DSList * list, char *key, unsigned int value, int cleanup)
{
	DSListElement *node;
	node = (DSListElement *) malloc (sizeof (DSListElement));
	ds_le_init (node);
	node->k.strKey = key;
	node->d.nData = value;
	node->next = list->head;
	node->flags = cleanup;
	ds_list_setHead (list, node);
	list->numElements++;
}

static void
ds_list_insert_nn (DSList * list, unsigned int key, unsigned int value,
				   int cleanup)
{
	DSListElement *node;
	node = (DSListElement *) malloc (sizeof (DSListElement));
	ds_le_init (node);
	node->k.nKey = key;
	node->d.nData = value;
	node->next = list->head;
	node->flags = cleanup;
	ds_list_setHead (list, node);
	list->numElements++;
}


static DSListElement **
ds_list_createSortArray (DSList * list)
{
	DSListElement **array;
	DSListElement *tmp;
	int i;
	array =
		(DSListElement **) malloc (sizeof (DSListElement) *
								   list->numElements);
	if (array == NULL)
		return NULL;
	for (i = 0, tmp = list->head; tmp; tmp = tmp->next, i++) {
		array[i] = tmp;
	}
	return array;
}

static void
ds_list_pushArray (DSList * list, DSListElement ** array, BOOL bDescend)
{
	unsigned int i;
	if (list->numElements == 0)
		return;
	if (bDescend) {
		for (i = 1; i < list->numElements; i++)
			array[i]->next = array[i - 1];
		array[0]->next = NULL;
		ds_list_setHead (list, array[list->numElements - 1]);
		list->tail = array[0];
	} else {
		for (i = 0; i < (list->numElements - 1); i++)
			array[i]->next = array[i + 1];
		array[list->numElements - 1]->next = NULL;
		list->tail = array[list->numElements - 1];
		ds_list_setHead (list, array[0]);
	}
}


static int
DSListQSort (DSListElement ** List, unsigned int li)
{
	DSListElement *midpoint;
	unsigned int FirstOffset;
	unsigned int LastOffset;
	unsigned int Temp;
	DSListElement *TempElement;
	int different = 0;
	if (li < 2)
		return TRUE;

	Temp = rand () % li;
	midpoint = List[Temp];

	FirstOffset = 0;
	LastOffset = li - 1;

	/* Scan from the beginning till the piles meet */
	for (FirstOffset = 0; FirstOffset < LastOffset; FirstOffset++) {
		if (strcmp (List[FirstOffset]->k.strKey, midpoint->k.strKey) >= 0) {
			/*
			 * If something needs to be in the other pile, find
			 * something in the other pile and swap them over
			 */
			for (; LastOffset > FirstOffset; LastOffset--) {
				if (strcmp (List[LastOffset]->k.strKey, midpoint->k.strKey) <
					0) {
					TempElement = List[LastOffset];
					List[LastOffset] = List[FirstOffset];
					List[FirstOffset] = TempElement;
					LastOffset--;
					break;
				}
			}
		}
	}
	FirstOffset = LastOffset;
	if (strcmp (List[LastOffset]->k.strKey, midpoint->k.strKey) < 0)
		FirstOffset++;
	/*
	 * If there's only one pile left (should be small) check it for
	 * equality.  If the elements are equal we're finished, if they're
	 * not we need to break again.
	 * String Addendum: This is much more costly than in the int version.
	 *  strcmp() is slow, and the increased chance of false breaks here
	 *  mean this happens more often.
	 */
	if (FirstOffset == 0 || FirstOffset == li) {
		for (Temp = 0; (Temp < li) && (!different); Temp++)
			if (strcmp (List[Temp]->k.strKey, List[0]->k.strKey))
				different = 1;
	}
	if ((FirstOffset && (li - FirstOffset)) || different) {
		/* If there are stuff in the piles, keep going */
		if (FirstOffset > 0)
			DSListQSort (List, FirstOffset);
		if ((li - FirstOffset) > 0) {
			DSListQSort (&List[FirstOffset], li - FirstOffset);
		}
	}
	return TRUE;
}

BOOL
ds_list_sortAsString (DSList * list)
{
	DSListElement **array;
	array = ds_list_createSortArray (list);
	if (array == NULL)
		return FALSE;
	DSListQSort (array, list->numElements);
	ds_list_pushArray (list, array, FALSE);
	free (array);
	return TRUE;
}

static unsigned int
hash_s (DSHashTable * hsh, unsigned char *input_value)
{
	unsigned int temp;
	temp = hsh->primeA;
	while (input_value[0] != '\0') {
		temp ^= (*input_value + (temp << 5) + (temp >> 2));
		input_value++;
	}
	return ((temp % hsh->primeB) % hsh->buckets);
}

static unsigned int
hash_n (DSHashTable * hsh, unsigned int input_value)
{
	return (input_value % hsh->buckets);
}


void
ds_hash_init (DSHashTable * hash, unsigned int newBuckets,
			  unsigned int newPrimeA, unsigned int newPrimeB)
{
	unsigned int i;
	hash->buckets = newBuckets;
	hash->primeA = newPrimeA;
	hash->primeB = newPrimeB;
	hash->bucket = (DSList **) malloc (sizeof (DSList *) * hash->buckets);
	for (i = 0; i < hash->buckets; i++) {
		hash->bucket[i] = (DSList *) malloc (sizeof (DSList));
		ds_list_init (hash->bucket[i]);
	}
}

void
ds_hash_close (DSHashTable * hash)
{
	unsigned int i;
	for (i = 0; i < hash->buckets; i++) {
		ds_list_close (hash->bucket[i]);
		free (hash->bucket[i]);
	}
	free (hash->bucket);
}

DSList *
ds_hash_getList (DSHashTable * hash)
{
	DSList *retval;
	unsigned int i;
	DSList *l;
	DSListElement *le;
	DSListElement *lenew;
	retval = (DSList *) malloc (sizeof (DSList));
	ds_list_init (retval);

	for (i = 0; i < hash->buckets; i++) {
		l = hash->bucket[i];
		for (le = l->head; le != NULL; le = le->next) {
			lenew = (DSListElement *) malloc (sizeof (DSListElement));
			ds_le_copy (lenew, le);
			lenew->flags = 0;
			ds_list_insert (retval, lenew);
		}
	}
	return retval;
}

void *
ds_hash_getPtrValue_s (DSHashTable * hsh, const char *Key)
{
	unsigned int bucket_num;
	bucket_num = hash_s (hsh, (unsigned char *) Key);
	return (ds_list_getPtrValue_s (hsh->bucket[bucket_num], Key));
}

void *
ds_hash_getPtrValue_n (DSHashTable * hsh, unsigned int Key)
{
	unsigned int bucket_num;
	bucket_num = hash_n (hsh, Key);
	return (ds_list_getPtrValue_n (hsh->bucket[bucket_num], Key));
}

unsigned int
ds_hash_getNumericValue_n (DSHashTable * hsh, unsigned int Key)
{
	unsigned int bucket_num;
	bucket_num = hash_n (hsh, Key);
	return (ds_list_getNumericValue_n (hsh->bucket[bucket_num], Key));
}


void
ds_hash_insert_ss (DSHashTable * hsh, char *Key, void *value, int cleanup)
{
	unsigned int bucket_num;
	bucket_num = hash_s (hsh, (unsigned char *) Key);
	ds_list_insert_ss (hsh->bucket[bucket_num], Key, value, cleanup);
}

void
ds_hash_insert_ns (DSHashTable * hsh, unsigned int Key, void *value,
				   int cleanup)
{
	unsigned int bucket_num;
	bucket_num = hash_n (hsh, Key);
	ds_list_insert_ns (hsh->bucket[bucket_num], Key, value, cleanup);
}

void
ds_hash_insert_sn (DSHashTable * hsh, char *Key, unsigned int value,
				   int cleanup)
{
	unsigned int bucket_num;
	bucket_num = hash_s (hsh, (unsigned char *) Key);
	ds_list_insert_sn (hsh->bucket[bucket_num], Key, value, cleanup);
}

void
ds_hash_insert_nn (DSHashTable * hsh, unsigned int Key, unsigned int value,
				   int cleanup)
{
	unsigned int bucket_num;
	bucket_num = hash_n (hsh, Key);
	ds_list_insert_nn (hsh->bucket[bucket_num], Key, value, cleanup);
}

#include <ctype.h>

void
ds_param_init (DSParams * para)
{
	para->lsmask = 0;
	para->lfmask = 0;
	ds_hash_init (&para->hsh, 20, DEF_PRIMEA, DEF_PRIMEB);
}

void
ds_param_close (DSParams * para)
{
	ds_hash_close (&para->hsh);
}

BOOL
ds_param_setFlagSwitch (DSParams * para, unsigned char c)
{
	int flag;

	if (!isalpha (c))
		return 0;
	c = tolower (c);
	flag = 1 << (c - 'a');
	para->lfmask = para->lfmask | flag;
	return TRUE;
}

BOOL
ds_param_setStringSwitch (DSParams * para, unsigned char c)
{
	int flag;
	if (!isalpha (c))
		return 0;
	c = tolower (c);
	flag = 1 << (c - 'a');
	para->lsmask = para->lsmask | flag;
	return TRUE;
}

BOOL
ds_param_process_argv (DSParams * para, int argc, char *argv[])
{
	int i;
	char c;
	int flag;
	char *upto;
	char *a;
	for (i = 1; i < argc; i++) {
		upto = argv[i];
		if (*upto == '-') {
			upto++;
			while (*upto) {
				c = (*upto);
				if (isalpha (c)) {
					c = tolower (c);
					flag = 1 << (c - 'a');
					if (flag & para->lsmask) {
						a = (char *) malloc (strlen (upto));
						strcpy (a, upto + 1);
						ds_hash_insert_ns (&para->hsh, c, a,
										   CLEANUP_VALUE_FREE);
						break;
					} else if (flag & para->lfmask) {
						ds_hash_insert_nn (&para->hsh, c, 1, 0);
					} else {
						printf ("WARNING: Flag %c unknown\n", c);
					}
				}
				upto++;
			}
		} else {
			/* Not flag */
//			a = (char *) malloc (strlen (upto) + 1);
//			strcpy (a, upto);
			ds_hash_insert_ns (&para->hsh, (unsigned int) 0, upto, 0);
		}
	}
	return TRUE;
}

BOOL
ds_param_process_str (DSParams * para, char *arg)
{
	char c;
	int flag;
	char *upto;
	char *a;
	upto = arg;
	while (upto) {
		if (*upto == '-') {
			upto++;
			while (*upto) {
				c = (*upto);
				if (isalpha (c)) {
					c = tolower (c);
					flag = 1 << (c - 'a');
					if (flag & para->lsmask) {
						a = (char *) malloc (strlen (upto));
						strcpy (a, upto + 1);
						ds_hash_insert_ns (&para->hsh, c, a,
										   CLEANUP_VALUE_FREE);
						break;
					} else if (flag & para->lfmask) {
						ds_hash_insert_nn (&para->hsh, c, 1, 0);
					} else {
						printf ("WARNING: Flag %c unknown\n", c);
					}
				}
				upto++;
			}
		} else {
			/* Not flag */
//			a = (char *) malloc (strlen (upto) + 1);
//			strcpy (a, upto);
			ds_hash_insert_ns (&para->hsh, (unsigned int) 0, upto, 0);
			upto++;
		}
		upto = strchr (upto, ' ');
	}
	return TRUE;
}
