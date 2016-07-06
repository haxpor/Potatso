//
//  radix.h
//  ShadowPath
//
//  Created by LEI on 5/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#ifndef radix_h
#define radix_h

#include <stdio.h>
#include <stdint.h>

#define RADIX_NO_VALUE      (uint32_t)0

typedef struct radix_node_st    radix_node_t;

struct radix_node_st {
    radix_node_t    *right;
    radix_node_t    *left;
    radix_node_t    *parent;
    char        value;
};

typedef struct {
    radix_node_t    *root;
    size_t          size;
} radix_tree_t;

radix_tree_t *radix_tree_create();

int radix32tree_insert(radix_tree_t *tree,
                       uint32_t key, uint32_t mask, char value);

int radix32tree_delete(radix_tree_t *tree,
                       uint32_t key, uint32_t mask);

char radix32tree_find(radix_tree_t *tree, uint32_t key);
void radix_tree_free(radix_tree_t *tree);

#endif /* radix_h */
