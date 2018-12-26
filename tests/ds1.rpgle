**FREE

Dcl-Ds DSTest Qualified Template;
  Name Char(20);
  Age  Int(3);
  Money Packed(11:2);
End-Ds;

Dcl-Pi DS1;
  pDS LikeDS(DSTest);
End-Pi;

pDS.Name = 'Yes...';
pDS.Age = pDS.Age * 2;
pDS.Money = pDS.Money * 2;

Return;