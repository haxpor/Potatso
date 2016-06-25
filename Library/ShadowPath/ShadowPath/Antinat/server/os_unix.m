/* ANTINAT
 * =======
 * This software is Copyright (c) 2002-04 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#ifdef HAVE_PTHREAD_H
#include <pthread.h>
#endif
#include <Foundation/Foundation.h>
#include <arpa/inet.h>

void
os_thread_init (os_thread_t * thr)
{
}

void
os_thread_close (os_thread_t * thr)
{
}


void
os_thread_detach (os_thread_t * thr)
{
	pthread_detach (thr->tid);
}

int
os_thread_exec (os_thread_t * thr, void *(*start) (void *), void *arg)
{
	pthread_attr_t atts;
	pthread_attr_init (&atts);
#ifdef HAVE_PTHREAD_ATTR_SETSCOPE
	pthread_attr_setscope (&atts, PTHREAD_SCOPE_SYSTEM);
#endif
#ifdef HAVE_PTHREAD_ATTR_SETSTACKSIZE
	pthread_attr_setstacksize (&atts, 256 * 1024);
#endif
	return !pthread_create (&thr->tid, &atts, start, arg);
}

void
os_mutex_init (os_mutex_t * lock)
{
	pthread_mutex_init (&lock->mutex, NULL);
}

void
os_mutex_close (os_mutex_t * lock)
{
	pthread_mutex_destroy (&lock->mutex);
}

void
os_mutex_lock (os_mutex_t * lock)
{
	pthread_mutex_lock (&lock->mutex);
}

void
os_mutex_unlock (os_mutex_t * lock)
{
	pthread_mutex_unlock (&lock->mutex);
}

//int
//os_pipe (int *ends)
//{
//    int client_fd = socket(AF_INET, SOCK_STREAM, 0);
//    int write_fd = socket(AF_INET, SOCK_STREAM, 0);
//    __block int read_fd = 0;
//    struct sockaddr_in addr;
//    addr.sin_family = AF_INET;
//    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
//    addr.sin_port = htons(0);
//    bind(write_fd, (struct sockaddr*)&addr, sizeof(addr));
//    struct sockaddr_in sin;
//    socklen_t len = sizeof(sin);
//    int port;
//    if (getsockname(write_fd, (struct sockaddr *)&sin, &len) < 0) {
//        NSLog(@"getsock_ip: getsockname() error: %s",
//              strerror (errno));
//        return -1;
//    }else{
//        port = ntohs(sin.sin_port);
//    }
//    int on = 1;
//    setsockopt (write_fd, SOL_SOCKET, SO_NOSIGPIPE, &on,
//                sizeof (on));
//    setsockopt (client_fd, SOL_SOCKET, SO_NOSIGPIPE, (char *) &on, sizeof (on));
//    dispatch_queue_t q = dispatch_queue_create("bind", DISPATCH_QUEUE_CONCURRENT);
//    dispatch_group_t group = dispatch_group_create();
//    dispatch_group_enter(group);
//    dispatch_async(q, ^(){
//        struct sockaddr_in client;
//        listen(write_fd, 5);
//        socklen_t alen = sizeof(client);
//        read_fd = accept(write_fd, (struct sockaddr *)&client, &alen);
//        dispatch_group_leave(group);
//    });
//    dispatch_async(q, ^(){
//        struct sockaddr_in server;
//        memset(&server, 0, sizeof(server));
//        server.sin_family = AF_INET;
//        server.sin_addr.s_addr = inet_addr("127.0.0.1");
//        server.sin_port = htons(port);
//        int ret = connect(client_fd, (struct sockaddr*)&server, sizeof(server));
//    });
//    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
//    ends[0] = client_fd;
//    ends[1] = read_fd;
////    fcntl(client_fd, F_SETFL, O_NONBLOCK);
////    fcntl(read_fd, F_SETFL, O_NONBLOCK);
//	return 0;
//}

int
os_pipe (int *ends)
{
    return pipe (ends);
}

#ifdef WITH_DEBUG
void
os_debug_log (const char *filename, const char *msg)
{
    time_t t = time(NULL);
	NSLog (@"antiant ====> %s %s: %s\n", ctime(&t), filename, msg);
}
#endif
