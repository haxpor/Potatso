//
//  events.c
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//
//  Copyright 2010 Mirek Rusin, Released under MIT License
//

//#import <Foundation/Foundation.h>
//#import "YAMLSerialization.h"

#include <stdlib.h>
#include <stdio.h>
#include "yaml.h"

#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>

#define PRINT_INDENT() for (int i = 0; i < indent; i++) printf("  ")


int
main(int argc, char *argv[])
{
  int number;
  
  if (argc < 2) {
    printf("Usage: %s file1.yaml ...\n", argv[0]);
    return 0;
  }
  
  for (number = 1; number < argc; number ++)
  {
    FILE *file;
    yaml_parser_t parser;
    yaml_event_t event;
    int done = 0;
    int count = 0;
    int error = 0;
    
    printf("[%d] Parsing '%s': \n", number, argv[number]);
    fflush(stdout);
    
    file = fopen(argv[number], "rb");
    assert(file);
    
    assert(yaml_parser_initialize(&parser));
    
    yaml_parser_set_input_file(&parser, file);
    
    int indent = 0;
    
    while (!done)
    {
      if (!yaml_parser_parse(&parser, &event)) {
        error = 1;
        break;
      }

      switch (event.type) {
        case YAML_NO_EVENT:
          break;
        case YAML_STREAM_START_EVENT:
          break;
        case YAML_STREAM_END_EVENT:
          break;
        case YAML_DOCUMENT_START_EVENT:
          printf("%%YAML 1.2\n---\n");
          break;
        case YAML_DOCUMENT_END_EVENT:
          break;
        case YAML_ALIAS_EVENT:
          PRINT_INDENT();
          printf("*%s\n", event.data.alias.anchor);
          break;
        case YAML_SCALAR_EVENT:
          PRINT_INDENT();
          if (event.data.scalar.anchor)
            printf("&%s ", event.data.scalar.anchor);
          printf("!!str \"%s\"\n", event.data.scalar.value);
          break;
        case YAML_SEQUENCE_START_EVENT:
          printf("seq,s\t\n");
          indent++;
          break;
        case YAML_SEQUENCE_END_EVENT:
          indent--;
          printf("seq,e\t\n");
          break;
        case YAML_MAPPING_START_EVENT:
          printf("!!map {\n");
          indent++;
          break;
        case YAML_MAPPING_END_EVENT:
          indent--;
          printf("}\n");
          break;
        default:
          printf("unkn\t\n");
          break;
      }
      done = (event.type == YAML_STREAM_END_EVENT);
      
      yaml_event_delete(&event);
      
      count ++;
    }
    
    yaml_parser_delete(&parser);
    
    assert(!fclose(file));
    
    printf("%s (%d events)\n", (error ? "FAILURE" : "SUCCESS"), count);
  }
  
  return 0;
}
