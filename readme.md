## ILEusion
Web server for ILEusion.
[Read more here on the documentation site](https://sitemule.github.io/ileusion/about).

## ILEusion Overview
ILEusion
ILEusion is an application whichs allows your IBM i reached from outside the OS over HTTP or Db2 stored procedure.

It provides services for:
- Calling programs and service programm functions.
- Running SQL queries.
- Working with data areas.
- Running commands (QSH, CL, etc)

### Documentation
- Installation   
https://sitemule.github.io/ileusion/installation   
- API documentation    
https://sitemule.github.io/ileusion/api

### Available libraries
ILEusion exists to replace XMLSERVICE with a nicer API layer so it is easier to work with. There are currently libraries for

- Node.js (ileusion_node) 
https://github.com/WorksOfBarry/ileusion_node    
- .NET Framework & .NET Core (ILEusion-DotNet) 
https://github.com/richardschoen/ILEusion-DotNet   

## ILEUsion API Documentation

### Starting the ILEusion Server
All APIs are enabled when the ILEusion server is started. You can start the server (or multiple servers) using the STRILESRV command after installation. The command also has optional parameters.
```
ADDLIBLE ILEASTIC
ADDLIBLE NOXDB
ADDLIBLE ILEUSION
STRILESRV
```

### API authorisation
All APIs are run within the same job, but in seperate threads.

If ```LOGIN```is enabled, when making a request to the ILEusion HTTP server you are required to pass the Authorization header with a Basic username and password (in base64). This does mean, that requests will run under the supplied user profile - it will use that users authorities, not the users that is running the ILEusion server. It is recommend that you call the ILEusion via an SSL enabled proxy to secure the username and password.

```Authorization: Basic bXl1c2VycHJmOm15cGFzc3dvcmQ=```   
If LOGIN is disabled, then it will use the user profile that started the ILEusion job and no Authorization header is needed.   

### Calling ILEusion through Db2
You are also able to call ILEusion APIs through a Db2 stored procedure. For example, you can use a database library in your Node.js or PHP app and that would use the database to authenticate the user (and manage their authorities). Then you can use the database to call the ILEusion stored procedure to call any of the available APIs.

Not yet implemented. See relevant GitHub issue

### API documentation
All APIs accept and respond with JSON. All APIs will return an object with success: false if it fails, along with message. Not all APIs return with success: true.

APIs available:
```
/transaction
/sql
/call
/dq/send
/dq/pop
/cl
/qsh
```
### /transaction
/transaction allows ILEusion to process multiple transaction in one request. Meaning you could call a program, insert into a data queue and call a CL command in a single API call.  

The body must be an array of objects, where the object is what matches the API you want to call (see the available API documentation) - but must also contain an action attribute which is the API it’s going to use.

**Example input**  
```
[  
   {  
      "action": "/dq/send",
      "library": "BARRY",
      "object": "TESTDQ",
      "data": "This is my test!!"
   },
   {  
      "action":"/cl",
      "command": "addliliohls"
   }
]
```
**Example response**  
```
[  
   {  
      "success": true
   },
   {  
      "success": false,
      "message": "Error during execution of command."
   }
]
```
### /sql
/sql allows you to run select statements.

The request body has 1 required and 2 optional attributes:

- query - required string, the SQL statement to be executed.
- parameters - optional object, a keyed list of SQL parameters to be in place of the provided markers. (See example)
- mode - optional number:
-  1 - execute a select statement and get a result set (default mode)
-  2 - execute a statement with no result set returned
-  3 - insert into a table. query attribute to be used for table name and parameters to be used as a keyed list for the columns (column: value)
-  4 - update a row in a table. query attribute to be used for table name, parameters to be used as a keyed list for the columns (column: value) to be updated. A third where attribute to specify the where clause.
**Example input** 
```
{
  "query": "select * from product where MANUID = 'SAMSUNG'"
}
{
  "query": "select * from product where MANUID = '$manu'",
  "parameters": {
    "manu": "SAMSUNG"
  }
}
{
  "mode": 4,
  "query": "product",
  "parameters": {
    "manu": "SAMSUNG"
  },
  "where": "prodno = 120"
}
```
### /call
/call allows you to call an ILE application or service program function. The result is an array of values which is the values passed by reference from the application. Currently only program calls are supported.

Request body

The request body has three main attributes:

- library - string, name of library
- object - string, name of program (or service program if using function attribute)
- function - string, name of function (optional, only required when calling export functions in a service program)

- result - object defining the return type of the function (optional, only needed if return type is not void)
- type - string, type of parameter: see Acceptable types
- length - number, should match length of type defined in the calling application (uses RPG sizes)
- precision - number, Only to be used with packed or zoned types.
- value - array of args, Only to be used with struct type.
- arraysize - number, size of array being returned (optional, only needed if functions returns an array)
- args - array of objects defining the parameters and their types:
- type - string, type of parameter: see Acceptable types
- length - number, should match length of type defined in the calling application (uses RPG sizes)
- precision - number, Only to be used with packed or zoned type.
- value - string/number/bool
- values - array, used if calling application has an array parameter. Not to be used at the same time as the value attribute
- Acceptable types: int, uns, float, char, bool, ind, packed, zoned, struct

Service program functions can be called, but you can only pass parameters in and out.
❗The return value is not being handled yet (23).   
❗You can also only call each service program once per transaction (24).

**Example request**
```
Dcl-Pi FAK100;
  pText Char(20);
  pNum1 Int(10);
  pNum2 Int(10);
  pNum3 Int(10);
End-Pi;
{
	"object": "FAK100",
	"library": "BARRY",
	"args": 
 	[
		{
			"value": "Text here",
			"type": "char",
			"length": 20
		},
		{
			"value": 11,
			"type": "int",
			"length": 10
		},
		{
			"value": 10,
			"type": "int",
			"length": 10
		},
		{
			"value": 0,
			"type": "int",
			"length": 10
		}
	]
}
```
**Example request (array)**
```
Dcl-Pi FAK101;
  pText Char(20);
  pNums Int(10) Dim(3);
End-Pi;
{
	"object": "FAK101",
	"library": "BARRY",
	"args": 
  [
		{
			"value": "John",
			"type": "char",
			"length": 20
		},
		{
			"values": [
				3,
				666,
				5
			],
			"type": "int",
			"length": 10
		}
	]
}
```
**Example request (struct)**
```
Dcl-Ds DSTest Qualified Template;
  Name Char(20);
  Age  Int(3);
  Money Packed(11:2);
End-Ds;

Dcl-Pi DS1;
  pDS LikeDS(DSTest);
End-Pi;
{
        "library": "ILEUSION",
        "object": "DS1",
        "args": [
            {
                "type": "struct",
                "value": [
                    {
                        "type": "char",
                        "length": 20,
                        "value": "Hello"
                    },
                    {
                        "type": "int",
                        "length": 3,
                        "value": 11
                    },
                    {
                        "type": "packed",
                        "length": 11,
                        "precision": 2,
                        "value": 12.34
                    }
                ]
            }
        ]
}
```
### /dq/send
/dq/send can be used to push items into a data queue.

**Request body**
- library - string, name of library
- object - string, name of program
- data - any, data to be pushed
- key - string, key of the item to be pushed (optional)
**Example request**  
```
{
	"library": "BARRY",
	"object": "TESTDQ",
	"data": "Hello world!"
}
```
**Example response**  
```
{
  "success": true
}
```
### /dq/recv
/dq/recv can be used to receive an item from a data queue.

**Request body**
- library - string, name of library
- object - string, name of program
- waittime - number, 0 by default (optional)
- key - string/number, key of the item to be popped (optional)
- keyorder - key comparison, EQ by default (optional)
**Example request**
```
{
	"library": "BARRY",
	"object": "TESTDQ"
}
```
**Example response**
```
{
  "success": true,
  "data": "Hello world!"
}
```
### /cl
/cl can be used to run a CL command in the same job as the ILEusion server.

**Request body**
- command - the command contents.

**Example request**  
```
{
  "command": "ADDLIBLE SYSTOOLS"
}
```
**Example response** 
```
{
  "success": true
}
```
### /qsh
/qsh can be used to run a QShell command in the same job as the ILEusion server.

**Request body**

- command - the command contents.
**Example request**
```
{
  "command": "mkdir xxx"
}
```
**Example response**
```
{
  "success": true,
  "returned": 0
}
```
