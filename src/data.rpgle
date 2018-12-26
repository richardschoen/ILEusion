**FREE

        Ctl-Opt NoMain;
        
        /copy ./headers/jsonparser.rpgle
        /copy ./headers/data_h.rpgle
        
        Dcl-C MAX_STRING 1024;
        
        Dcl-Ds CurrentArg_T Qualified Template;
          ArraySize   Int(5);
          ByteSize    Int(5); //Size of type for each element
          Type        Char(10);
          Length      Int(5); //Variable length for each element
          Scale       Int(3);
          Offset      Int(5);
        End-Ds;
        
        Dcl-Ds Types Qualified Template;
          int3   Int(3)   Pos(1);
          int5   Int(5)   Pos(1);
          int10  Int(10)  Pos(1);
          int20  Int(20)  Pos(1);
          uns3   Uns(3)   Pos(1);
          uns5   Uns(5)   Pos(1);
          uns10  Uns(10)  Pos(1);
          uns20  Uns(20)  Pos(1);
          float  Float(4) Pos(1);
          double Float(8) Pos(1);
        End-Ds;
        
        Dcl-Pr str_2_packed Int(10) ExtProc(*CWIDEN:'str_2_packed');
          Output Pointer Value;
          Input  Pointer Value;
          Dim    Int(10) Value;
          Length Int(10) Value;
          Scale  Int(10) Value;
        End-Pr;
        
        Dcl-Pr packed_2_str Int(10) ExtProc(*CWIDEN:'packed_2_str');
          Output Pointer Value;
          Input  Pointer Value;
          Length Int(10) Value;
          Scale  Int(10) Value;
        End-Pr;
        
        Dcl-Pr str_2_zoned Int(10) ExtProc(*CWIDEN:'str_2_zoned');
          Output Pointer Value;
          Input  Pointer Value;
          Dim    Int(10) Value;
          Length Int(10) Value;
          Scale  Int(10) Value;
        End-Pr;
        
        Dcl-Pr zoned_2_str Int(10) ExtProc(*CWIDEN:'zoned_2_str');
          Output Pointer Value;
          Input  Pointer Value;
          Length Int(10) Value;
          Scale  Int(10) Value;
        End-Pr;
        
        // -------------------------
        
        Dcl-Proc Get_Result Export;
        
          Dcl-Pi *N Pointer;
            pCurrentArg Pointer; //Info about the current argument
            pValue      Pointer Value; //Value pointer
          End-Pi;
          
          Dcl-S  lIndex     Int(5);
          Dcl-S  lTotal     Int(5);
          Dcl-S  lArray     Pointer;
          Dcl-S  lResult    Varchar(MAX_STRING);
          Dcl-DS ValuePtr   LikeDS(Types);
          Dcl-Ds CurrentArg LikeDS(CurrentArg_T);
          
          Dcl-S  StructRes   Pointer;
          Dcl-S  ValuesPtr   Pointer;
          Dcl-DS ArrayElem   LikeDS(JSON_ITERATOR);
          Dcl-DS StructEle   LikeDS(JSON_ITERATOR);
          
          Dcl-s SomeString Char(1024);
          
          Dcl-s  lDecimalRes Char(32);

          CurrentArg.Type        = JSON_GetStr(pCurrentArg:'type');
          CurrentArg.Length      = JSON_GetNum(pCurrentArg:'length':1);
          CurrentArg.Scale       = JSON_GetNum(pCurrentArg:'precision':0);
          CurrentArg.ByteSize    = JSON_GetNum(pCurrentArg:'bytesize':0);
          CurrentArg.ArraySize   = JSON_GetNum(pCurrentArg:'arraysize':1);
          
          //Apply the offset incase is a subfield
          CurrentArg.Offset = JSON_GetNum(pCurrentArg:'offset':0);
          pValue += CurrentArg.Offset;
          
          If (CurrentArg.ByteSize = 0);
            CurrentArg.ByteSize = GetByteSize(CurrentArg);
          Endif;

          If (CurrentArg.ByteSize > 0);
            lIndex = 0;
            lArray = JSON_NewArray();
            lTotal = CurrentArg.ByteSize * CurrentArg.ArraySize;

            Dow (lIndex < lTotal);
              memcpy(%Addr(ValuePtr):pValue+lIndex:%Size(ValuePtr));
                
              Select;
                When (CurrentArg.Type = 'struct');
                  SomeString = json_AsJsonText(pCurrentArg);
                  ValuesPtr = JSON_Locate(pCurrentArg:'values');
                  ArrayElem = JSON_SetIterator(ValuesPtr);
                  
                  Dow JSON_ForEach(ArrayElem);
                    StructEle = JSON_SetIterator(ArrayElem.this);
                    
                    Dow JSON_ForEach(StructEle);
                      SomeString = json_AsJsonText(StructEle.this);
                      StructRes = Get_Result(StructEle.this:pValue+lIndex);
                      
                      If (JSON_GetLength(StructRes) = 1);
                        JSON_ArrayPush(lArray:JSON_GetChild(StructRes));
                      Else;
                        JSON_ArrayPush(lArray:StructRes);
                      Endif;
                    Enddo;
                    
                  Enddo;
                  
                  lResult = '*OMIT';
              
                When (CurrentArg.Type = 'char');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  
                When (CurrentArg.Type = 'bool');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  If (lResult = '1');
                    lResult = 'true';
                  Else;
                    lResult = 'false';
                  Endif;
                  
                When (CurrentArg.Type = 'ind');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  
                When (CurrentArg.Type = 'int');
                  Select;
                    When (CurrentArg.Length = 3);
                      lResult = %Char(ValuePtr.int3);
                    When (CurrentArg.Length = 5);
                      lResult = %Char(ValuePtr.int5);
                    When (CurrentArg.Length = 10);
                      lResult = %Char(ValuePtr.int10);
                    When (CurrentArg.Length = 20);
                      lResult = %Char(ValuePtr.int20);
                  Endsl;
                  
                When (CurrentArg.Type = 'uns');
                  Select;
                    When (CurrentArg.Length = 3);
                      lResult = %Char(ValuePtr.uns3);
                    When (CurrentArg.Length = 5);
                      lResult = %Char(ValuePtr.uns5);
                    When (CurrentArg.Length = 10);
                      lResult = %Char(ValuePtr.uns10);
                    When (CurrentArg.Length = 20);
                      lResult = %Char(ValuePtr.uns20);
                  Endsl;
                
                When (CurrentArg.Type = 'float');
                  Select;
                    When (CurrentArg.Length = 4);
                      lResult = %Char(ValuePtr.float);
                    When (CurrentArg.Length = 8);
                      lResult = %Char(ValuePtr.double);
                  Endsl;
                  
                When (CurrentArg.Type = 'packed');
                  packed_2_str(%Addr(lDecimalRes):pValue+lIndex
                              :CurrentArg.Length:CurrentArg.Scale);
                  lResult = %TrimR(lDecimalRes);
                  
                When (CurrentArg.Type = 'zoned');
                  zoned_2_str(%Addr(lDecimalRes):pValue+lIndex
                              :CurrentArg.Length:CurrentArg.Scale);
                  lResult = %TrimR(lDecimalRes);
              Endsl;
              
              If (lResult <> '*OMIT');
                JSON_ArrayPush(lArray:lResult);
              Endif;
              
              lIndex += CurrentArg.ByteSize;
            Enddo;

          Endif;
          
          Return lArray;
        End-Proc;
          
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Data Export;
          Dcl-Pi *N Pointer;
            pCurrentArg Pointer;
          End-Pi;
          
          Dcl-S lArray  Pointer Inz(*NULL);
          Dcl-S lResult Pointer Inz(*NULL);

          Dcl-S  TotalSize  Int(5);
          Dcl-Ds CurrentArg LikeDS(CurrentArg_T);

          lArray = JSON_Locate(pCurrentArg:'values');

          if (lArray = *NULL);
            CurrentArg.ArraySize = 1;
            lArray = json_MoveObjectInto(pCurrentArg:'values':JSON_NewArray());
            JSON_ArrayPush(lArray:JSON_GetStr(pCurrentArg:'value')
                          :JSON_COPY_CLONE);
          
            json_NodeDelete(JSON_Locate(pCurrentArg:'value'));
          Else;
            CurrentArg.ArraySize = JSON_GetLength(lArray);
          Endif;

          CurrentArg.Type     = JSON_GetStr(pCurrentArg:'type');
          CurrentArg.Length   = JSON_GetNum(pCurrentArg:'length':1);
          CurrentArg.Scale    = JSON_GetNum(pCurrentArg:'precision':0);
          CurrentArg.ByteSize = GetByteSize(CurrentArg:lArray);
          CurrentArg.Offset   = 0;
          
          If (CurrentArg.ByteSize > 0);
            JSON_SetNum(pCurrentArg:'bytesize':CurrentArg.ByteSize);
            JSON_SetNum(pCurrentArg:'arraysize':CurrentArg.ArraySize);

            TotalSize = CurrentArg.ByteSize * CurrentArg.ArraySize;
            If (CurrentArg.Type = 'char');
              TotalSize += 1; //Null term string
            Endif;

            lResult = %Alloc(TotalSize);
            AppendValues(lResult:lArray:CurrentArg);
          Endif;

          Return lResult;
        End-Proc;
          
        // -----------------------------------------------------------------------------
        
        Dcl-Proc GetByteSize;
          Dcl-Pi *N Int(5);
            pCurrentArg LikeDS(CurrentArg_T);
            pValArray   Pointer Options(*NoPass);
          End-Pi;
          
          Dcl-S  ByteSize  Int(5) Inz(0);
          
          Dcl-DS Subfield  LikeDS(CurrentArg_T);
          Dcl-S  Structure Pointer;
          Dcl-S  ValuesArr Pointer;
          
          Dcl-DS ArrElement likeds(JSON_ITERATOR);
          Dcl-DS SubfieldP  likeds(JSON_ITERATOR);
          
          Dcl-S SomeString Char(1024);
          
          Select;
            When (pCurrentArg.Type = 'struct');
              ByteSize = 0;
              //'values' attribute (array)
              ArrElement = JSON_SetIterator(pValArray);
              Dow JSON_ForEach(ArrElement);
              
                //Reset the struct bytesize for each struct
                ByteSize = 0;
                
                //Each item in values array (is an array of subfields)
                SubfieldP = JSON_SetIterator(ArrElement.this);
                Dow JSON_ForEach(SubfieldP);
                  Subfield.Type     = JSON_GetStr(SubfieldP.this:'type');
                  Subfield.Length   = JSON_GetNum(SubfieldP.this:'length':1);
                  Subfield.Scale    = JSON_GetNum(SubfieldP.this:'precision':0);
                  
                  ValuesArr = JSON_Locate(SubfieldP.this:'values');
                  
                  //Calculate array size of elements
                  if (ValuesArr = *NULL);
                    Subfield.ArraySize = 1;
                    ValuesArr = json_MoveObjectInto(SubfieldP.this
                                                   :'values':JSON_NewArray());
                    JSON_ArrayPush(ValuesArr:JSON_GetStr(SubfieldP.this
                                                        :'value')
                                                        :JSON_COPY_CLONE);
                                                        
                    json_NodeDelete(JSON_Locate(SubfieldP.this:'value'));
                  Else;
                    Subfield.ArraySize = JSON_GetLength(ValuesArr);
                  Endif;
                  
                  Subfield.ByteSize = GetByteSize(Subfield);
                  
                  //We also set the offsets so we can use these later :p
                  JSON_SetNum(SubfieldP.this:'offset':ByteSize);
                  JSON_SetNum(SubfieldP.this:'bytesize':Subfield.ByteSize);
                  JSON_SetNum(SubfieldP.this:'arraysize':Subfield.ArraySize);
                  
                  ByteSize += (Subfield.ByteSize*Subfield.ArraySize);
                Enddo;
                
              Enddo;
          
            When (pCurrentArg.Type = 'char');
              ByteSize = pCurrentArg.Length;
              
            When (pCurrentArg.Type = 'bool');
              ByteSize = 2;
              
            When (pCurrentArg.Type = 'ind');
              ByteSize = 2;
              
            When (pCurrentArg.Type = 'int');
              Select;
                When (pCurrentArg.Length = 3);
                  ByteSize = %Size(Types.int3);
                When (pCurrentArg.Length = 5);
                  ByteSize = %Size(Types.int5);
                When (pCurrentArg.Length = 10);
                  ByteSize = %Size(Types.int10);
                When (pCurrentArg.Length = 20);
                  ByteSize = %Size(Types.int20);
              Endsl;
              
            When (pCurrentArg.Type = 'uns');
              Select;
                When (pCurrentArg.Length = 3);
                  ByteSize = %Size(Types.uns3);
                When (pCurrentArg.Length = 5);
                  ByteSize = %Size(Types.uns5);
                When (pCurrentArg.Length = 10);
                  ByteSize = %Size(Types.uns10);
                When (pCurrentArg.Length = 20);
                  ByteSize = %Size(Types.uns20);
              Endsl;
            
            When (pCurrentArg.Type = 'float');
              Select;
                When (pCurrentArg.Length = 4);
                  ByteSize = %Size(Types.float);
                When (pCurrentArg.Length = 8);
                  ByteSize = %Size(Types.double);
              Endsl;
              
            When (pCurrentArg.Type = 'packed');
              ByteSize = pCurrentArg.Length/2+1;
              
            When (pCurrentArg.Type = 'zoned');
              ByteSize = pCurrentArg.Length;
          Endsl;
          
          Return ByteSize;
        End-Proc;
        
        // -----------------------------------------------------------------------------

        Dcl-Proc AppendValues;
          Dcl-Pi *N;
            pResult Pointer;
            pArray  Pointer;
            pArg    LikeDS(CurrentArg_T);
          End-Pi;

          Dcl-S  ValueChar Char(16);
          Dcl-Ds ValuePtr  LikeDS(Types);
          Dcl-S  lIndex    Int(5);
          Dcl-DS lList     likeds(JSON_ITERATOR);
          
          Dcl-S  SubfValues Pointer;
          Dcl-DS Subfields likeds(JSON_ITERATOR);
          Dcl-Ds Subfield  LikeDS(CurrentArg_T);

          lIndex = pArg.Offset;
          lList = JSON_SetIterator(pArray); //Array: value
          Dow JSON_ForEach(lList);
            Select;
              When (pArg.type = 'struct');
                Subfields = JSON_SetIterator(lList.this);
                Dow JSON_ForEach(Subfields);
                
                  Subfield.Type      = JSON_GetStr(Subfields.this:'type');
                  Subfield.Length    = JSON_GetNum(Subfields.this:'length':1);
                  Subfield.Scale     = JSON_GetNum(Subfields.this:'precision':0);
                  Subfield.ByteSize  = JSON_GetNum(Subfields.this:'bytesize':0);
                  Subfield.ArraySize = JSON_GetNum(Subfields.this:'arraysize':1);
                  Subfield.Offset    = JSON_GetNum(Subfields.this:'offset':0);
                  
                  SubfValues = JSON_Locate(Subfields.this:'values');
                  AppendValues(pResult:SubfValues:Subfield);
                Enddo;
            
              When (pArg.Type = 'char');
                %Str(pResult+lIndex:pArg.ByteSize) = JSON_GetStr(lList.this);
                
              When (pArg.Type = 'bool');
                If (JSON_GetStr(lList.this) = 'true');
                  %Str(pResult+lIndex:pArg.ByteSize) = '1';
                Else;
                  %Str(pResult+lIndex:pArg.ByteSize) = '0';
                Endif;
                
              When (pArg.Type = 'ind');
                %Str(pResult+lIndex:pArg.ByteSize) = JSON_GetStr(lList.this);
                
              When (pArg.Type = 'int');
                Select;
                  When (pArg.Length = 3);
                    ValuePtr.int3 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 5);
                    ValuePtr.int5 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 10);
                    ValuePtr.int10 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 20);
                    ValuePtr.int20 = %Int(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
                
              When (pArg.Type = 'uns');
                Select;
                  When (pArg.Length = 3);
                    ValuePtr.uns3 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 5);
                    ValuePtr.uns5 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 10);
                    ValuePtr.uns10 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 20);
                    ValuePtr.uns20 = %Uns(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
              
              When (pArg.Type = 'float');
                Select;
                  When (pArg.Length = 4);
                    ValuePtr.float = %Float(JSON_GetStr(lList.this));
                  When (pArg.Length = 8);
                    ValuePtr.double = %Float(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
                
              When (pArg.Type = 'packed');
                ValueChar = JSON_GetStr(lList.this);
                str_2_packed(pResult+lIndex:%Addr(ValueChar):1
                            :pArg.Length:pArg.Scale);
                            
              When (pArg.Type = 'zoned');
                ValueChar = JSON_GetStr(lList.this);
                str_2_zoned(pResult+lIndex:%Addr(ValueChar):1
                            :pArg.Length:pArg.Scale);
            Endsl;

            lIndex += pArg.ByteSize;
          Enddo;
        End-Proc;