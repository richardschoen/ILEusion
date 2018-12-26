        
        Ctl-Opt NoMain;
        
        Dcl-C MAX_BUFFER 1024;
        
        Dcl-Proc callfunc Export;
          Dcl-Pi *N Pointer;
            pProc Pointer(*Proc);
            pArgv Pointer Dim(256);
            pArgc Uns(3);
          End-Pi;
          
          Dcl-S lResultC Char(MAX_BUFFER);
          
          Dcl-Pr PARM0 Like(lResultC) ExtProc(pProc);
          End-Pr;
          Dcl-Pr PARM1 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM2 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM3 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM4 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM5 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM6 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM7 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          Dcl-Pr PARM8 Like(lResultC) ExtProc(pProc);
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value;
            *N Pointer Value; 
            *N Pointer Value;
            *N Pointer Value;
          End-Pr;
          
          Select;
            When (pArgc = 0);
              lResultC = PARM0();
            When (pArgc = 1);
              lResultC = PARM1(pArgv(1));
            When (pArgc = 2);
              lResultC = PARM2(pArgv(1):pArgv(2));
            When (pArgc = 3);
              lResultC = PARM3(pArgv(1):pArgv(2):pArgv(3));
            When (pArgc = 4);
              lResultC = PARM4(pArgv(1):pArgv(2):pArgv(3):pArgv(4));
            When (pArgc = 5);
              lResultC = PARM5(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5));
            When (pArgc = 6);
              lResultC = PARM6(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6));
            When (pArgc = 7);
              lResultC = PARM7(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6):pArgv(7));
            When (pArgc = 8);
              lResultC = PARM8(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6):pArgv(7):pArgv(8));
          Endsl;
          
          Return %Addr(lResultC);
        End-Proc;