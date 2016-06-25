# YAML.framework for Objective-C

Based on C `LibYAML` library (`http://pyyaml.org/wiki/LibYAML`) by Kirill Simonov.

`YAML.framework` provides support for YAML (de/)serialisation similarly to standard `NSPropertyListSerialization`.

It's fast and compatible with iOS.

## Example usage

```objc
NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath: @"yaml/items.yaml"];
// or [[NSInputStream alloc] initWithURL: ...]

// You can use objectsWithYAMLStream:options:error instead to get all YAML documents.
//
// Alternativelly object(s)WithYAMLData:options:error or object(s)WithYAMLString:options:error.
id yaml = [YAMLSerialization objectWithYAMLStream: stream
                                          options: kYAMLReadOptionStringScalars
                                            error: nil];

// Dump Objective-C object description.
printf("%s", [[yaml description] UTF8String]);
```

For input YAML file:

```yaml
items:
  - name: Foo
  - name: Bar
```

Should print dump string similar to:

``` 
(
  {
    items = (
      {
        name = Foo;
      },
      {
        name = Bar;
      }
    );
  }
)
```

## API

The following class methods are defined on `YAMLSerialization` class. 

### Reading YAML

```objc
// Returns all document objects from parsed YAML stream.
+ (NSMutableArray *) objectsWithYAMLStream: (NSInputStream *) stream
                                   options: (YAMLReadOptions) opt
                                     error: (NSError **) error;

// Returns all document objects from parsed YAML data.
+ (NSMutableArray *) objectsWithYAMLData: (NSData *) data
                                 options: (YAMLReadOptions) opt
                                   error: (NSError **) error;

// Returns all document objects from parsed YAML string.
+ (NSMutableArray *) objectsWithYAMLString: (NSString *) string
                                   options: (YAMLReadOptions) opt
                                     error: (NSError **) error;

// Returns first object from parsed YAML stream.
+ (id) objectWithYAMLStream: (NSInputStream *) stream
                    options: (YAMLReadOptions) opt
                      error: (NSError **) error;

// Returns first object from parsed YAML data.
+ (id) objectWithYAMLData: (NSData *) data
                  options: (YAMLReadOptions) opt
                    error: (NSError **) error;

// Returns first object from parsed YAML string.
+ (id) objectWithYAMLString: (NSString *) string
                    options: (YAMLReadOptions) opt
                      error: (NSError **) error;
```

### Writing YAML

```objc
// Returns YES on success, NO otherwise.
+ (BOOL) writeObject: (id) object
        toYAMLStream: (NSOutputStream *) stream
             options: (YAMLWriteOptions) opt
               error: (NSError **) error;

// Caller is responsible for releasing returned object.
+ (NSData *) createYAMLDataWithObject: (id) object
                              options: (YAMLWriteOptions) opt
                                error: (NSError **) error NS_RETURNS_RETAINED;

// Returns autoreleased object.
+ (NSData *) YAMLDataWithObject: (id) object
                        options: (YAMLWriteOptions) opt
                          error: (NSError **) error;

// Caller is responsible for releasing returned object.
+ (NSString *) createYAMLStringWithObject: (id) object
                                  options: (YAMLWriteOptions) opt
                                    error: (NSError **) error NS_RETURNS_RETAINED;

// Returns autoreleased object.
+ (NSString *) YAMLStringWithObject: (id) object
                            options: (YAMLWriteOptions) opt
                              error: (NSError **) error;
```

## License

`YAML.framework` is released under the MIT license.

    Copyright (c) 2010 Mirek Rusin (YAML.framework)
                  2006 Kirill Simonov (LibYAML)

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
    of the Software, and to permit persons to whom the Software is furnished to do
    so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
