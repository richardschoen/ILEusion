**FREE

Dcl-Pi FAK103;
  pName     Char(20);
  pPacked   Zoned(11:2);
End-Pi;

Dcl-s lName Char(20);

lName = %Str(%Addr(pName));

pPacked = pPacked * 2;

pName = 'Bye ' + %Trim(lName) + ' ' + %Char(pPacked);

Return;