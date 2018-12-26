          
        Dcl-Pr Get_Result Pointer ExtProc;
          pCurrentArg Pointer; //Info about the current argument
          pValue      Pointer Value; //Value pointer
        End-Pr;
        
        Dcl-Pr Generate_Data Pointer ExtProc;
          pCurrentArg Pointer;
        End-Pr;
          
        Dcl-Pr memcpy ExtProc('__memcpy');
          target Pointer Value;
          source Pointer Value;
          length Uns(10) Value;
        End-Pr;