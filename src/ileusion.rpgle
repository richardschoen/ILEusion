
        // -----------------------------------------------------------------------------
        // Start it:
        // SBMJOB CMD(CALL PGM(ILEUSION)) JOB(ILEASTIC1) JOBQ(QSYSNOMAX) ALWMLTTHD(*YES)
        // -----------------------------------------------------------------------------     
        
        ctl-opt copyright('Sitemule.com  (C), 2018');
        ctl-opt decEdit('0,') datEdit(*YMD.) main(main);
        ctl-opt debug(*yes);
        ctl-opt thread(*CONCURRENT);
        
        /include ./headers/actions_h.rpgle
        /include ./headers/ILEastic.rpgle
        /include ./headers/jsonparser.rpgle
        
        Dcl-C PW_LEN 128;
        
        Dcl-DS ErrorDS_t Qualified Template;
          bytesPrv      Int(10)    Pos(1) INZ(256);
          bytesAvl      Int(5)    Pos(5) INZ(0);
          errMsgID      Char(7)    Pos(9);
          reserved      Char(1)    Pos(16);
          errMsgDta     Char(240)  Pos(17);
        End-Ds;

        // -----------------------------------------------------------------------------
        // Main
        // -----------------------------------------------------------------------------
        
        //If *on, no auth header is needed and will use the server user profile
        Dcl-S gNoLogin Ind Inz(*On) Static(*ALLTHREAD);
        
        dcl-proc main;
          Dcl-Pi *N;
            gHost        Char(15);
            gPort        Int(10);
            gLogin       Char(1);
          End-Pi;

          dcl-ds config likeds(il_config);

          config.host = %TrimR(gHost);
          config.port = gPort;
          gNoLogin = (gLogin = '0');

          il_listen (config : %paddr(myservlet));

        end-proc;
        
        // -----------------------------------------------------------------------------
        // Servlet call back implementation
        // -----------------------------------------------------------------------------
        
        dcl-proc myservlet;

          dcl-pi *n;
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lAuthheader Char(128);
          Dcl-S ResultLength Int(10);
          
          Dcl-S lIndex Int(3);
          Dcl-Ds UserInfo Qualified;
            Username Char(10);
            Password Char(PW_LEN);
            Handle   Char(12);
          End-Ds;
          
          Dcl-S lEndpoint   Varchar(128);
          Dcl-S lMethod     Varchar(10);
          Dcl-S lDocument   Pointer;
          Dcl-S lResponse   Pointer;
          
          Dcl-Ds ErrorDS LikeDS(ErrorDS_t);
          
          lEndpoint = il_getRequestResource(request);
          lMethod   = il_getRequestMethod(request);
          
          response.contentType = 'application/json';
          
          If (lMethod = 'POST');
          
            lAuthheader = il_getRequestHeader(request : 'Authorization');
            
            //Either we need the header OR no login is required
            If (%Len(lAuthheader) > 6 OR gNoLogin);
            
              If (NOT gNoLogin);
                lAuthheader = %Subst(lAuthheader:7);
                lAuthheader = %TrimR(lAuthheader);
                
                //Eventually will have to base64 decode here.
                lAuthheader = il_decodeBase64(lAuthheader);
                            
                lIndex = %Scan(':':lAuthheader);
                UserInfo.Username = %Subst(lAuthheader:1:lIndex-1);
                UserInfo.Password = %Subst(lAuthheader:lIndex+1);
              Endif;
              
              UserInfo.Handle = Authorise(UserInfo.Username
                                         :UserInfo.Password
                                         :ErrorDS);
              
              Select;
                When (UserInfo.Handle = *Blank);
                  lResponse = Generate_Error('Login handle incorrect.');
                  
                When (ErrorDS.errMsgID <> *Blank);
                  lResponse = Generate_Error('Login error occured.'
                                            :ErrorDS.errMsgID);
                  
                Other;
                  lDocument = JSON_ParseString(request.content.string);
                  If (JSON_Error(lDocument));
                    lResponse = Generate_Error('Error parsing JSON.');
                    
                  Else;
                    
                    SetUserHandle(UserInfo.Handle);
                    
                    lResponse = Handle_Action(il_getRequestResource(request)
                                             :lDocument);
                                             
                    EndUserHandle(UserInfo.Handle:ErrorDS);
                  Endif;
              Endsl;
              
            Else;
              lResponse = Generate_Error('Requires basic authorization.');
            Endif;
          
          Else;
            lResponse = Generate_Error('Requires POST request.');
          Endif;
          
          If (lResponse <> *NULL);
            il_responseWriteStream(response : json_stream(lResponse));
            JSON_NodeDelete(lResponse);
          Endif;
          
          JSON_NodeDelete(lDocument);
          
        end-proc;
        
        //**********************************
        
        Dcl-Proc Authorise;
          Dcl-Pi *N Char(12);
            pUsername Char(10);
            pPassword Char(PW_LEN); 
            pErrorDS  LikeDS(ErrorDS_t);
          End-Pi;
          
          Dcl-Pr GetHandle ExtProc('QsyGetProfileHandle');
            Handle   Char(12);
            Username Pointer Value;
            Password Pointer Value;
            PwLen    Int(10) Value;
            PwCCSID  Uns(10) Value;
            ErrorDS  Pointer Value;
          End-Pr;
          
          Dcl-S lHandle Char(12);
          
          If (NOT gNoLogin);
            GetHandle(lHandle
                     :%Addr(pUsername):%Addr(pPassword)
                     :%Len(%TrimR(pPassword)):0
                     :%Addr(pErrorDS));
            
            Return lHandle;
          Else;
            Return 'NOLOGIN';
          Endif;
        End-Proc;
        
        //**********************************
        
        Dcl-Proc SetUserHandle;
          Dcl-Pi *N;
            pHandle Char(12);
          End-Pi;
          
          Dcl-Pr SetHandle ExtProc('QsySetToProfileHandle');
            Handle Pointer Value;
          End-Pr;
          
          If (NOT gNoLogin);
            SetHandle(%Addr(pHandle));
          Endif;
        End-Proc;
        
        //**********************************
        
        Dcl-Proc EndUserHandle;
          Dcl-Pi *N;
            pHandle Char(12);
            pErrorDS  LikeDS(ErrorDS_t);
          End-Pi;
          
          Dcl-Pr EndHandle ExtProc('QsyReleaseProfileHandle');
            Handle Pointer Value;
            ErrorDS  Pointer Value;
          End-Pr;
          
          If (NOT gNoLogin);
            EndHandle(%Addr(pHandle):%Addr(pErrorDS));
          Endif;
        End-Proc;