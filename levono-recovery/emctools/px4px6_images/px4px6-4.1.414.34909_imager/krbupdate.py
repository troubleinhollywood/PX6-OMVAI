#!/usr/bin/python
import fileinput

KRB5FILE = "/etc/krb5.conf"
domain_name = "";
buffer = "";

def checkDomain():
        global domain_name
        for line in fileinput.input(KRB5FILE):
                if (line.find('default_realm') != -1):
                        tmp = line;
                        import re
                        tmparray = re.split('[=]',tmp);
                        domain = re.sub('[ \n]', '', tmparray[1])
                        domain_name = domain+" ="
                if (line.find('[realms]') != -1):
                        return -1

def modifykrbconf():
        global domain_name
        global buffer

        for line in fileinput.input(KRB5FILE):
                if (line.find(domain_name) != -1):
                        buffer +="[realms]\n"
                buffer += line;

def writebuffer():
        #print buffer
        f = open(KRB5FILE, 'w')
        f.write(buffer)
        f.close()


def main():
        ret = checkDomain()
        if(ret == None):
                if(domain_name != 0):
                        modifykrbconf()
                        writebuffer()
main()

