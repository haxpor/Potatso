//
//  radix.c
//  ShadowPath
//
//  Created by LEI on 5/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#include <stdlib.h>
#include <sys/types.h>
#include "radix.h"

static void *radix_alloc(radix_tree_t *tree);

radix_tree_t *radix_tree_create() {
    radix_tree_t *tree = (radix_tree_t *)malloc(sizeof(*tree));
    if (!tree) {
        return NULL;
    }

    tree->size = 0;
    tree->root = (radix_node_t *)radix_alloc(tree);
    if (!tree->root) {
        return NULL;
    }

    tree->root->right = NULL;
    tree->root->left = NULL;
    tree->root->parent = NULL;
    tree->root->value = RADIX_NO_VALUE;

    return tree;
}

/* Need a 'mask' parameter is for storage of CIDR. */
int radix32tree_insert(radix_tree_t *tree, uint32_t key,
                       uint32_t mask, char value) {
    uint32_t        bit;
    radix_node_t    *node, *next;
    bit = 0x80000000;
    node = tree->root;
    next = tree->root;

    /* find a place in trie to insert */
    while (bit & mask) {
        if (key & bit) {
            next = node->right;
        } else {
            next = node->left;
        }

        if (!next) {
            break;
        }
        bit >>= 1;
        node = next;
    }

    if (next) {
        if (node->value != RADIX_NO_VALUE) {
            return 1;   /* Return 1 when the node has been existed */
        }

        node->value = value;
        return 0;
    }

    /* inserting value in trie creating all path components */
    while (bit & mask) {
        next = radix_alloc(tree);
        if (!next) {
            return -1;
        }

        next->right = NULL;
        next->left = NULL;
        next->parent = node;
        next->value = RADIX_NO_VALUE;

        if (key & bit) {
            node->right = next;
        } else {
            node->left = next;
        }

        bit >>= 1;
        node = next;
    }

    node->value = value;
    return 0;
}

int radix32tree_delete(radix_tree_t *tree, uint32_t key, uint32_t mask) {
    uint32_t        bit;
    radix_node_t    *node, *tmp;

    bit = 0x80000000;
    node = tree->root;

    while (node && (bit & mask)) {
        if (key & bit) {
            node = node->right;
        } else {
            node = node->left;
        }
        bit >>= 1;
    }

    if (!node || !node->parent) {
        return -1;
    }

    if (node->right || node->left) {
        if (node->value != RADIX_NO_VALUE) {
            node->value = RADIX_NO_VALUE;
            return 0;
        }
        return -1;
    }

    for ( ; ; ) {
        if (node->parent->right == node) {
            node->parent->right = NULL;
        } else {
            node->parent->left = NULL;
        }

        tmp = node;
        node = node->parent;
        free(tmp);

        if (node->right || node->left) {
            break;
        }

        if (node->value != RADIX_NO_VALUE) {
            break;
        }

        if (node->parent == NULL) {
            break;
        }
    }

    return 0;
}

char radix32tree_find(radix_tree_t *tree, uint32_t key) {
    uint32_t        bit;
    uint32_t        value;
    radix_node_t    *node;

    bit = 0x80000000;
    value = RADIX_NO_VALUE;
    if (NULL == tree) {
        return value;
    }
    node = tree->root;

    while (node) {
        if (node->value != RADIX_NO_VALUE) {
            value = node->value;
        }

        if (key & bit) {
            node = node->right;
        } else {
            node = node->left;
        }
        bit >>= 1;
    }

    return value;
}

static void *radix_alloc(radix_tree_t *tree) {
    char *p = (char *)malloc(sizeof(radix_node_t));
    if (p) {
        tree->size += sizeof(radix_node_t);
    }
    return p;
}

void radix_tree_free(radix_tree_t *tree) {
    radix_node_t *node, *tmp;

    node = tree->root;
    for ( ; ; ) {
        /* We are at the trie root and we have no more leaves,
         * end of algorithm */
        if (!node->left && !node->right && !node->parent) {
            free(node);
            break;
        }

        /* Traverse to the end of trie */
        while (node->left || node->right) {
            if (node->left) {
                node = node->left;
            } else {
                node = node->right;
            }
        }

        /* Found leaf node, free it */
        if (node->parent->right == node) {
            node->parent->right = NULL;
        } else {
            node->parent->left = NULL;
        }
        
        tmp = node;
        
        /* Go up */
        node = node->parent;
        free(tmp);
    }
}