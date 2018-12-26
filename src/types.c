
#define hex_nbr 0xF0

int str_2_zoned(char * where, char *str, int tdim, int tlen, int tscale) {
  int i = 0;
  int j = 0;
  int k = 0;
  int outDigits = tlen;
  int outDecimalPlaces = tscale;
  int outLength = outDigits;
  int inLength = 0;
  int sign = 0;
  char chr[256];
  char dec[256];
  char * c;
  char * wherev = where;

  /* fix up input */
  c = chr;
  inLength = ile_pgm_str_fix_decimal(str, tlen, tscale, c, sizeof(chr), &sign);

  /* convert string to zoned */
  /* write correct number of leading zero's */
  for (i=0; i < outDigits-inLength; i++) {
    dec[j++] = (char)0xF0;
  }
  /* place all the digits except the last one */
  while (j < outLength-1) {
    dec[j++] = (char)((c[k++] & 0x000F) | 0x00F0);
  }
  /* place the sign and last digit */
  if (!sign) {
    dec[j++] = (char)((c[k++] & 0x000F) | 0x00F0);
  } else {
    dec[j++] = (char)((c[k++] & 0x000F) | 0x00D0);
  }
  /* copy in */
  for (i=0; i < tdim; i++, wherev += outLength) {
    memcpy(wherev, dec, outLength);
  }
  return 0;
}

int str_2_packed(char * where, char *str, int tdim, int tlen, int tscale) {
  int i = 0;
  int j = 0;
  int k = 0;
  int outDigits = tlen;
  int outDecimalPlaces = tscale;
  int outLength = outDigits/2+1;
  int inLength = 0;
  int sign = 0;
  char chr[256];
  char dec[256];
  char * c;
  int leadingZeros = 0;
  int firstNibble = 0;
  int secondNibble = 0;
  char * wherev = where;

  /* fix up input */
  c = chr;
  inLength = ile_pgm_str_fix_decimal(str, tlen, tscale, c, sizeof(chr), &sign);

  /* convert string to packed */
  if (outDigits % 2 == 0) {
   leadingZeros = outDigits - inLength + 1;
  } else {
   leadingZeros = outDigits - inLength;
  }
  /* write correct number of leading zero's */
  for (i=0; i<leadingZeros-1; i+=2) {
    dec[j++] = 0;
  }
  if (leadingZeros > 0) {
    if (leadingZeros % 2 != 0) {
      dec[j++] = (char)(c[k++] & 0x000F);
    }
  }
  /* place all the digits except last one */
  while (j < outLength-1) {
    firstNibble = (char)(c[k++] & 0x000F) << 4;
    secondNibble = (char)(c[k++] & 0x000F);
    dec[j++] = (char)(firstNibble + secondNibble);
  }
  /* place last digit and sign nibble */
  firstNibble = (char)(c[k++] & 0x000F) << 4;
  if (!sign) {
    dec[j++] = (char)(firstNibble + 0x000F);
  }
  else {
    dec[j++] = (char)(firstNibble + 0x000D);
  }
  /* copy in */
  for (i=0; i < tdim; i++, wherev += outLength) {
    memcpy(wherev, dec, outLength);
  }
  return 0;
}

int ile_pgm_str_fix_decimal(char *str, int tlen, int tscale, char * buf, int len, int *sign) {
  int i = 0;
  int j = 0;
  char chr[256];
  char * a;
  char * c;
  int mint = 0;
  int aint = 0;
  int adot = 0;
  int mscale = 0;
  int ascale = 0;
  int inLength = 0;
  int trimLength = 0;
  int overflow = 0;

  /* zero user buffer */
  memset(buf,0,len);
  /* character zero buffer correct length (user) */
  memset(buf,'0',tlen);

  /* parse input string */
  c = str;
  inLength = strlen(c);
  if (inLength) {
    memset(chr,0,sizeof(chr));
    for (i=0, j=0; i < inLength; i++) {
      if (c[i] == '-') {
        *sign = 1;
      } else {
        if (ile_pgm_isnum_digit(c[i])) {
          chr[j++] = c[i];
          if (adot) {
            ascale++;
          } else {
            aint++;
          }
        }
      }
      if (!adot && c[i] == '.') {
          adot = 1;
      }
    }
    /* max char int (front) */
    if (tlen > tscale) {
      mint = tlen - tscale;
    }
    /* max char scale (back) */
    if (tscale) {
      mscale = tscale;
    }
    /* round scale (back) */
    if (ascale > mscale) {
      overflow = ile_pgm_str_fix_round(chr, strlen(chr), mscale);
    }
    /* copy out */
    a = chr;
    c = buf;
    /* integer too large (trunc front) */
    if (aint > mint) {
      i = 0;
      j = aint - mint;
      aint = mint;
    /* integer ok (front) */
    } else {
      i = mint - aint;
      j = 0;
    }
    for (ascale=0; i < tlen; i++) {
      if (aint) {
        c[i] = a[j++];
        aint--;
      } else {
        /* trunc scale (back) */
        if (ascale < mscale) {
          c[i] = a[j++];
        }
        ascale++;
      }
    }
  } /* inLength */
 
  return tlen;
}

int ile_pgm_isnum_digit(char c) {
  if (c >= '0' && c <= '9') {
    return 1;
  }
  return 0;
}

int ile_pgm_str_fix_round(char *str, int tlen, int tscale) {
  int i = 0;
  int overflow = 0;
  char * c = str;

  for (i=tlen-1;i && tscale;i--) {
    if (overflow || i == tlen-tscale) {
      if (overflow) {
        overflow = 0;
        switch(c[i-1]) {
        case '0':
          c[i-1] = '1';
          break;
        case '2':
          c[i-1] = '2';
          break;
        case '3':
          c[i-1] = '3';
          break;
        case '4':
          c[i-1] = '5';
          break;
        case '5':
          c[i-1] = '6';
          break;
        case '6':
          c[i-1] = '7';
          break;
        case '7':
          c[i-1] = '8';
          break;
        case '8':
          c[i-1] = '9';
          break;
        case '9':
          c[i-1] = '0';
          overflow = 1;
          if (tscale && i == tlen-tscale) {
            tscale--;
          }
          break;
        }
      }
    } else { 
      if (i > tlen-tscale && (c[i] > '5' && c[i-1] >= '5')) {
        c[i] = '0';
        switch(c[i-1]) {
        case '5':
          c[i-1] = '6';
          break;
        case '6':
          c[i-1] = '7';
          break;
        case '7':
          c[i-1] = '8';
          break;
        case '8':
          c[i-1] = '9';
          break;
        case '9':
          c[i-1] = '0';
          overflow = 1;
          if (tscale && i == tlen-tscale) {
            tscale--;
          }
          break;
        }
      }
    }
    if (tscale < 1 || i == tlen-tscale) {
      break;
    }
  }
  return overflow;
}

int zoned_2_str(char * res, char * where, int tlen, int tscale) {
  int i = 0;
  int j = 0;
  int k = 0;
  int l = 0;
  int isOk = 0;
  int isDot = 0;
  int isScale = 0;
  char * wherev = (char *) where;
  int outDigits = tlen;
  int outLength = outDigits;
  int leftDigitValue = 0;
  int rightDigitValue = 0;
  char * c;
  char str[128];
  for (i=0, j = 0; i < 1; i++, wherev += outLength) {
    memset(str,0,sizeof(str));
    /* sign negative */
    c = wherev;
    leftDigitValue = (char)((c[outLength-1] >> 4) & 0x0F);
    if (leftDigitValue == 0x0D) {
      str[j++] = '-';
    }
    for (k=0, l=0, isOk=0, isDot=0, isScale=0; k < outLength; k++) {
      /* digits */
      leftDigitValue = (char)((c[k] >> 4) & 0x0F);
      /* decimal point */
      if (!isDot && tscale && l >= tlen - tscale) {
        if (!isOk) {
          str[j++] = (char) hex_nbr;
        }
        str[j++] = '.';
        isDot = 1;
        isOk = 1;
      }
      l++;
      /* digits */
      rightDigitValue = (char)(c[k] & 0x0F);
      if (isOk || rightDigitValue > 0) {
        str[j++] = (char)(hex_nbr + rightDigitValue);
        isOk = 1;
        if (isDot) {
          isScale++;
        }
      }
    }
    /* zero */
    if (!isOk) {
      str[j++] = (char) hex_nbr;
      str[j++] = '.';
      isOk = 1;
      isDot = 1;
      isScale = 0;
    }
    /* one significant decimal */
    if (isDot && !isScale) {
      str[j++] = (char) hex_nbr;
    }
    memcpy(res, str, outLength);
    j = 0; /* Brian s with dim */
  }
  return 0;
}

int packed_2_str(char * res, char * where, int tlen, int tscale) {
	int tdim = 1;
  int i = 0;
  int j = 0;
  int k = 0;
  int l = 0;
  int isOk = 0;
  int isDot = 0;
  int isScale = 0;
  char * wherev = (char *) where;
  int outDigits = tlen;
  int outLength = outDigits/2+1;
  int actLen = outLength * 2;
  int leftDigitValue = 0;
  int rightDigitValue = 0;
  char * c;
  char str[128];
  for (i=0, j=0; i < tdim; i++, wherev += outLength) {
    memset(str,0,sizeof(str));
    /* sign negative */
    c = wherev;
    rightDigitValue = (char)(c[outLength-1] & 0x0F);
    if (rightDigitValue == 0x0D) {
      str[j++] = '-';
    }
    for (k=0, l=0, isOk=0, isDot=0, isScale=0; k < outLength; k++) {
      /* decimal point */
      l++;
      if (!isDot && tscale && l >= actLen - tscale) {
        if (!isOk) {
          str[j++] = (char) hex_nbr;
        }
        str[j++] = '.';
        isDot = 1;
        isOk = 1;
      }
      /* digits */
      leftDigitValue = (char)((c[k] >> 4) & 0x0F);
      if (isOk || leftDigitValue > 0) {
        str[j++] = (char)(hex_nbr + leftDigitValue);
        isOk = 1;
        if (isDot) {
          isScale++;
        }
      }
      /* decimal point */
      l++;
      if (!isDot && tscale && l >= actLen - tscale) {
        if (!isOk) {
          str[j++] = (char) hex_nbr;
        }
        str[j++] = '.';
        isDot = 1;
        isOk = 1;
      }
      /* digits */
      rightDigitValue = (char)(c[k] & 0x0F);
      if (k < outLength-1 && (isOk || rightDigitValue > 0)) {
        str[j++] = (char)(hex_nbr + rightDigitValue);
        isOk = 1;
        if (isDot) {
          isScale++;
        }
      }
    }
    /* zero */
    if (!isOk) {
      str[j++] = (char) hex_nbr;
      str[j++] = '.';
      isOk = 1;
      isDot = 1;
      isScale = 0;
    }
    /* one significant decimal */
    if (isDot && !isScale) {
      str[j++] = (char) hex_nbr;
    }
    memcpy(res, str, outLength);
    j = 0; /* Brian s with dim */
  }
  return 0;
}