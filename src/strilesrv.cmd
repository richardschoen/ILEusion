
             CMD Prompt('Start ILEusion Server')
             PARM KWD(job)  TYPE(*CHAR) LEN(10) PROMPT('Job Name') + 
                  DFT(ILEUSION)
             PARM KWD(host) TYPE(*CHAR) LEN(15) PROMPT('Host IP') + 
                  DFT(*ANY)
             PARM KWD(port) TYPE(*INT4) PROMPT('Port') DFT(8008)
             PARM KWD(login) +                                 
                  TYPE(*CHAR) LEN(1) + 
                  SPCVAL((*NO 0) (*YES 1)) DFT(*NO) +
                  PROMPT('Basic auth required')