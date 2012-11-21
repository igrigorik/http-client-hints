#!/bin/sh

# Create EPub file from RFC2629-formatted source
# 
# Copyright (c) 2010, Julian Reschke (julian.reschke@greenbytes.de)
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of Julian Reschke nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

if [ $# != 1 ] ; then
  echo Usage: $0 xmlsourcefile >&2
  exit 2
fi

if [ ! -r $1 ] ; then
  echo $0: can\'t read $1
  exit 1
fi

base=$(basename $1 .xml)
epub=$base.epub
tmpfolder=mkepubtmp-$$

xslt() {
  if type saxon >/dev/null 2> /dev/null; then
    saxon $1 $2 basename=$base 
  elif type xsltproc >/dev/null 2> /dev/null; then
    xsltproc --stringparam basename $base $2 $1 
  else
    echo $0: needs either "saxon" or "xsltproc" >&2
  fi
}


(
  mkdir $tmpfolder
  cd $tmpfolder
  echo "application/epub+zip\c" > mimetype
  mkdir META-INF
  echo '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
' > META-INF/container.xml
  mkdir OEBPS
  xslt ../$1 ../rfc2629toOpf.xslt > OEBPS/content.opf
  xslt ../$1 ../rfc2629toNcx.xslt > OEBPS/toc.ncx
  xslt ../$1 ../rfc2629toEPXHTML.xslt > OEBPS/$base.xhtml
  xslt ../$1 ../extractInlineCss.xslt > OEBPS/rfc2629xslt.css
  xslt ../$1 ../extractExtRefs.xslt | while read filename
  do
    cp ../$filename OEBPS/
  done
  
  [ -r ../$epub ] && rm ../$epub
  zip ../$epub -X0 mimetype
  zip ../$epub -Xr META-INF OEBPS
)
rm -rfv $tmpfolder
