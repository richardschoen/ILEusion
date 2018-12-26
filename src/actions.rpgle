        
        Ctl-Opt NoMain;
        ctl-opt debug(*yes);
        
        /include ./headers/actions_h.rpgle
        /include ./headers/ILEastic.rpgle
        /include ./headers/jsonparser.rpgle
        /include ./headers/data_h.rpgle
        /include ./headers/callfunc_h.rpgle
        
        //Am assuming is threadsafe?
        Dcl-s errmsgid char(7) import('_EXCP_MSGID');
        
        Dcl-Pr GetLibraryPointer extproc('_RSLVSP2');
          Object  Pointer;
          Options Char(34);
        End-Pr;
        
        Dcl-Pr GetObjectPointer extproc('_RSLVSP4');
          Object  Pointer;
          Options Char(34);
          Library Pointer;
        End-Pr;
        
        Dcl-Pr ActivateServiceProgram Int(20) ExtProc('QleActBndPgmLong');
          Object Pointer;
        End-Pr;
        
        Dcl-Pr RetrieveFunctionPointer Pointer ExtProc('QleGetExpLong');
          Mark          Int(20); //From ActivateServiceProgram
          ExportNum     Int(10) Value;  //Can pass 0
          ExportNameLen Int(10);  //Length
          ExportName    Pointer Value Options(*String); //Name
          rFuncPointer  Pointer; //Return pointer
          rFuncResult   Int(10);  //Return status code
        End-Pr;
     
        Dcl-Pr callpgmv extproc('_CALLPGMV');
          pgm_ptr Pointer;
          argv    Pointer Dim(256);
          argc    Uns(10) Value;
        End-Pr;
        
        Dcl-Pr QSHCommand Int(10) ExtProc('QzshSystem');
          *N Pointer Value Options(*String);
        End-Pr;
        
        Dcl-C DQ_LEN 16384;
        
        Dcl-Pr DQSend ExtPgm('QSNDDTAQ');
          Object  Char(10);
          Library Char(10);
          DataLen Packed(5);
          Data    Char(DQ_LEN);
          KeyLen  Packed(3) Options(*NoPass);
          Key     Pointer   Options(*NoPass);
        End-Pr;
        
        Dcl-Pr DQPop ExtPgm('QRCVDTAQ');
          Object   Char(10);
          Library  Char(10);
          DataLen  Packed(5);
          Data     Char(DQ_LEN);
          WaitTime Packed(5);
          KeyOrder Char(2)   Options(*NoPass);
          KeyLen   Packed(3) Options(*NoPass);
          Key      Pointer   Options(*NoPass);
        End-Pr;

        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_Action Export;
          Dcl-Pi *N Pointer;
            pEndpoint Char(128) Const;
            pDocument Pointer;
          End-Pi;
          
          Dcl-S  lResponse Pointer;
          
          Dcl-s  lResArray Pointer;
          Dcl-S  lEndpoint Char(128);
          Dcl-DS lList     likeds(JSON_ITERATOR);
          
          Select;
            When (pEndpoint = '/transaction' OR pEndpoint = '');
              lList = JSON_SetIterator(pDocument); //Array body is expected.
              lResArray = JSON_NewArray();
              dow JSON_ForEach(lList);
                lEndpoint = json_GetStr(lList.this:'action');
                lResponse = Handle_Action(lEndpoint:lList.this);
                json_ArrayPush(lResArray:lResponse:JSON_COPY_CLONE);
              enddo;
              lResponse = lResArray;
              
            When (pEndpoint = '/sql');
              lResponse = Handle_SQL(pDocument);
            When (pEndpoint = '/call');
              lResponse = Handle_Call(pDocument);
            When (pEndpoint = '/dq/send');
              lResponse = Handle_DataQueue_Send(pDocument);
            When (pEndpoint = '/dq/pop');
              lResponse = Handle_DataQueue_Pop(pDocument);
            When (pEndpoint = '/cl');
              lResponse = Handle_CL_Command(pDocument);
            When (pEndpoint = '/qsh');
              lResponse = Handle_QSH_Command(pDocument);
            Other;
              lResponse = Generate_Error('Incorrect action: '
                         + %TrimR(pEndpoint));
          Endsl;
          
          Return lResponse;
        End-Proc;
        
        // -----------------------------------------------------------------------------

        Dcl-Proc Handle_SQL;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-S lResult    Pointer;
          
          Dcl-S lResultSet Pointer;
          Dcl-S lSQLStmt   Pointer;
          Dcl-S lParms     Pointer;
          Dcl-S lMode      Int(3);
          
          lMode    = JSON_GetNum(lDocument:'mode':1);
          lSQLStmt = JSON_Locate(lDocument:'query');
          lParms   = JSON_Locate(lDocument:'parameters');
          
          If (lSQLStmt <> *NULL);
          	
          	Select;
          	  When (lMode = 1); //select
          	  	lResultSet = JSON_sqlResultSet(json_GetValuePtr(lSQLStmt)
          	  	                              :1:JSON_ALLROWS:0:lParms);
		            
		            If (JSON_Error(lResultSet));
		              lResult = Generate_Error(JSON_Message(lResultSet));
		              
		            Else;
		              lResult = lResultSet;
		            Endif;
		            
          	  When (lMode = 2); //exec
          	  	If (json_sqlExec(json_GetValuePtr(lSQLStmt):lParms));
          	  		lResult = Generate_Error(JSON_Message(lResultSet));
          	  	Else;
          	  		lResult = JSON_NewObject();
          				JSON_SetBool(lResult:'success':*On);
          	  	Endif;
		            
          	  When (lMode = 3); //insert
          	  	If (json_sqlInsert(json_GetValuePtr(lSQLStmt):lParms));
          	  		lResult = Generate_Error('Insert failed.');
          	  	Else;
          	  		lResult = JSON_NewObject();
          				JSON_SetBool(lResult:'success':*On);
          	  	Endif;
		            
          	  When (lMode = 4); //update
          	    lResultSet = JSON_Locate(lDocument:'where');
          	  	If (json_sqlUpdate(json_GetValuePtr(lSQLStmt):lParms
          	  	   :json_GetValuePtr(lResultSet)));
          	  	   
          	  		lResult = Generate_Error('Update failed.');
          	  	Else;
          	  		lResult = JSON_NewObject();
          				JSON_SetBool(lResult:'success':*On);
          	  	Endif;
          	Endsl;
            
            JSON_sqlDisconnect();
            
          Else;
            lResult = Generate_Error('Missing SQL statement.');
          Endif;
          
          return lResult;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_Call;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-S  lArray    Pointer; //Params array JSON document
          Dcl-S  lResponse Pointer; //Response JSON document
          Dcl-DS lList     likeds(JSON_ITERATOR);
          
          Dcl-Ds ProgramInfo Qualified;
            Library  Char(10);
            Name     Char(10);
            Function Varchar(32);
            argv     Pointer Dim(256) Inz(*NULL);
            argc     Uns(3);
            Threaded Ind Inz(*Off); //As in is multithread capable
            
            LibPtr  Pointer;
            CallPtr Pointer; //Pointer to object or function
          End-Ds;
          
          Dcl-S lResParm   Pointer; //Parameter return document
          Dcl-S lIndex     Uns(3);
          
          Dcl-S MakeCall   Ind Inz(*On);  //Used to determine whether a valid call
          Dcl-S IsFunction Ind Inz(*Off); //If true, func call, otherwise pgm
          
          Dcl-S lLength    Int(10);
          Dcl-S lMark      Int(20); //Reference to activated srvpgm
          Dcl-S lExportRes Int(10) Inz(-1); //Result of RetrieveFunctionPointer
          Dcl-S lFuncRes   Pointer; //Function result
          
          Dcl-Ds rslvsp Qualified;
            Obj_Type Char(2);
            Obj_Name Char(30);
            Auth     Char(2)  inz(x'0000');
          End-Ds;
          
          Monitor;
            MakeCall = *On;
            
            ProgramInfo.Library  = JSON_GetStr(lDocument:'library');
            ProgramInfo.Name     = JSON_GetStr(lDocument:'object');
            ProgramInfo.argc     = 0;
            ProgramInfo.Threaded = JSON_IsTrue(lDocument:'multithread'); //Default *off
            
            If (JSON_Locate(lDocument:'function') <> *NULL);
              ProgramInfo.Function = JSON_GetStr(lDocument:'function');
              IsFunction = *On;
            Endif;
            
            rslvsp.Obj_Type = x'0401';
            rslvsp.Obj_name = ProgramInfo.Library;
            GetLibraryPointer(ProgramInfo.LibPtr:rslvsp);
            
            If (IsFunction);
              rslvsp.Obj_Type = x'0203'; //Service program
            Else;
              rslvsp.Obj_Type = x'0201'; //Regular program
            Endif;
            
            rslvsp.Obj_name = ProgramInfo.Name;
            GetObjectPointer(ProgramInfo.CallPtr:rslvsp:ProgramInfo.LibPtr);
            
            //If it's a function, then get the function pointer
            If (IsFunction);
              lLength = %Len(ProgramInfo.Function);
              lMark = ActivateServiceProgram(ProgramInfo.CallPtr);
              RetrieveFunctionPointer(lMark
                                     :0
                                     :lLength
                                     :ProgramInfo.Function
                                     :ProgramInfo.CallPtr
                                     :lExportRes);
            Endif;
            
            //Now generate the parameters.
            lList = JSON_SetIterator(lDocument:'args'); //Array: value, type
            dow JSON_ForEach(lList);
              ProgramInfo.argc += 1;
              ProgramInfo.argv(ProgramInfo.argc) = Generate_Data(lList.this);
              
              If (ProgramInfo.argv(ProgramInfo.argc) = *NULL);
                MakeCall = *Off;
                Leave;
              Endif;
            enddo;
        
          On-Error *All;
            lResponse = Generate_Error('Error parsing request.');
            MakeCall = *Off;
          Endmon;

          //**************************
          
          If (MakeCall);
            Monitor;
              If (NOT ProgramInfo.Threaded);
              	il_enterThreadSerialize();
              Endif;
              
              If (IsFunction);
                lFuncRes = callfunc(ProgramInfo.CallPtr 
                                   :ProgramInfo.argv 
                                   :ProgramInfo.argc);
              Else;
                callpgmv(ProgramInfo.CallPtr 
                        :ProgramInfo.argv 
                        :ProgramInfo.argc);
              Endif;
              
              If (NOT ProgramInfo.Threaded);
                il_exitThreadSerialize();
              Endif;
              
              lResponse = JSON_NewObject();
              lArray = JSON_NewArray();
              lIndex  = 0;
              
              //Get the parameters back out incase they have changed (by ref)
              lList = JSON_SetIterator(lDocument:'args'); //Array: value, type
              dow JSON_ForEach(lList);
                lIndex += 1;
                
                lResParm = Get_Result(lList.this:ProgramInfo.argv(lIndex));
                
                If (JSON_GetLength(lResParm) = 1);
                  JSON_ArrayPush(lArray:JSON_GetChild(lResParm));
                Else;
                  JSON_ArrayPush(lArray:lResParm);
                Endif;

              enddo;
              
              JSON_moveObjectInto(lResponse:'args':lArray);
              
              //If it's a function, get the result!
              If (IsFunction);
                lResParm = JSON_Locate(lDocument:'result');
                If (lResParm <> *Null);
                  lResParm = Get_Result(lResParm
                                       :lFuncRes);
                                       
                  If (JSON_GetLength(lResParm) = 1);
                    JSON_SetPtr(lResponse:'result':JSON_GetChild(lResParm));
                  Else;
                    JSON_SetPtr(lResponse:'result':lResParm);
                  Endif;
                Endif;
              Endif;
              
            On-Error *All;
              lResponse = Generate_Error('Error making call.');
            Endmon;
          Endif;
          
          //Also deallocate everything :)
          For lIndex = 1 to ProgramInfo.argc;
            Dealloc ProgramInfo.argv(lIndex);
          Endfor;
          
          Return lResponse;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_DataQueue_Send;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-S lResponse Pointer;
          
          Dcl-Ds DQInfo Qualified;
            Library  Char(10);
            Object   Char(10);
            DataLen  Packed(5);
            DataChar Char(DQ_LEN);
            KeyLen   Packed(3);
            KeyPtr   Pointer;
          End-Ds;
          
          DQInfo.Library = JSON_GetStr(lDocument:'library':'');
          DQInfo.Object  = JSON_GetStr(lDocument:'object':'');
          
          DQInfo.DataLen  = %Len(JSON_GetStr(lDocument:'data':''));
          DQInfo.DataChar = JSON_GetStr(lDocument:'data':'');
          
          DQInfo.KeyLen  = %Len(JSON_GetStr(lDocument:'key':''));
          DQInfo.KeyPtr = JSON_GetValuePtr(JSON_Locate(lDocument:'key'));
          
          Monitor;
            If (DQInfo.KeyLen = 0); //No key
              DQSend(DQInfo.Object
                    :DQInfo.Library
                    :DQInfo.DataLen
                    :DQInfo.DataChar);
            Else;
              DQSend(DQInfo.Object
                    :DQInfo.Library
                    :DQInfo.DataLen
                    :DQInfo.DataChar
                    :DQInfo.KeyLen
                    :DQInfo.KeyPtr);
            Endif;
            
            //json_GetValuePtr
            lResponse = JSON_NewObject();
            JSON_SetBool(lResponse:'success':*On);
            
          On-Error *All;
            lResponse = Generate_Error('Error sending to data queue.');
          Endmon;
          
          Return lResponse;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_DataQueue_Pop;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-S lResponse Pointer;
          
          Dcl-Ds DQInfo Qualified;
            Library  Char(10);
            Object   Char(10);
            DataLen  Packed(5);
            DataChar Char(DQ_LEN);
            Waittime Packed(5);
            KeyOrder Char(2);
            KeyLen   Packed(3);
            KeyPtr   Pointer;
          End-Ds;
          
          DQInfo.Library  = JSON_GetStr(lDocument:'library':'');
          DQInfo.Object   = JSON_GetStr(lDocument:'object':'');
          DQInfo.Waittime = JSON_GetNum(lDocument:'waittime':0);
          DQInfo.KeyOrder = JSON_GetStr(lDocument:'keyorder':'EQ');
          DQInfo.KeyLen   = %Len(JSON_GetStr(lDocument:'key':''));
          DQInfo.KeyPtr   = JSON_GetValuePtr(lDocument:'key');
          
          Monitor;
            If (DQInfo.KeyLen = 0); //No key
              DQPop(DQInfo.Object
                    :DQInfo.Library
                    :DQInfo.DataLen
                    :DQInfo.DataChar
                    :DQInfo.Waittime);
            Else;
              DQPop(DQInfo.Object
                    :DQInfo.Library
                    :DQInfo.DataLen
                    :DQInfo.DataChar
                    :DQInfo.Waittime
                    :DQInfo.KeyOrder
                    :DQInfo.KeyLen
                    :DQInfo.KeyPtr);
            Endif;
            
            //json_GetValuePtr
            lResponse = JSON_NewObject();
            JSON_SetBool(lResponse:'success':*On);
            JSON_SetNum(lResponse:'length':DQInfo.DataLen);
            JSON_SetStr(lResponse:'value':%Subst(DQInfo.DataChar
                                                :1:DQInfo.DataLen));
            
          On-Error *All;
            lResponse = Generate_Error('Error sending to data queue.');
          Endmon;
          
          Return lResponse;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_CL_Command;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-Pr system int(10) extproc('system');
            cmdstring pointer value options(*string);
          End-Pr;
          
          Dcl-S lResponse Pointer;
          Dcl-S lCommand  Pointer;
          Dcl-S lCode     Int(3);
          
          lCommand = JSON_Locate(lDocument:'command');
          
          il_enterThreadSerialize();
          lCode = system(json_GetValuePtr(lCommand));
          
          If (lCode = 0);
            lResponse = JSON_NewObject();
            JSON_SetBool(lResponse:'success':*On);
          Else;
            lResponse = Generate_Error('Failed to execute CL command.'
                                      :errmsgid);
          Endif;
          
          //We end here because we need access to errmsgid
          il_exitThreadSerialize();
          
          Return lResponse;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_QSH_Command;
          dcl-pi *n Pointer;
            lDocument Pointer;
          end-pi;
          
          Dcl-S lResponse Pointer;
          Dcl-S lReturned Int(10);
          
          Monitor;
            il_enterThreadSerialize();
            lReturned = QSHCommand(JSON_GetStr(lDocument:'command':''));
            il_exitThreadSerialize();
            lResponse = JSON_NewObject();
            
            JSON_SetNum(lResponse:'returned':lReturned);
            JSON_SetBool(lResponse:'success':*On);
          On-Error *All;
            lResponse = Generate_Error('Error during execution of command.');
          Endmon;
          
          Return lResponse;
          
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Error Export;
          Dcl-Pi *N Pointer;
            pMessage   Pointer Value Options(*String);
            pErrorCode Pointer Value Options(*String:*NoPass);
          End-Pi;
          
          Dcl-S lResult Pointer;
          
          lResult = JSON_newObject();
          JSON_SetBool(lResult:'success':*Off);
          JSON_SetStr(lResult:'message': pMessage);
          
          If (pErrorCode <> *Null);
            JSON_SetStr(lResult:'code': pErrorCode);
          Endif;
          
          return lResult;
        End-Proc;
