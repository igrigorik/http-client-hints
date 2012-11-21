<!--
    XSLT transformation from RFC2629 XML format to OPF file format

    Copyright (c) 2009-2010, Julian Reschke (julian.reschke@greenbytes.de)
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of Julian Reschke nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
-->

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns="http://www.idpf.org/2007/opf"
               version="1.0"
>

<xsl:import href="rfc2629.xslt"/>

<xsl:output indent="yes" method="xml" version="1.0" encoding="UTF-8"/>

<xsl:param name="basename"/>

<xsl:template match="/">
  <xsl:variable name="uri">
    <xsl:choose>
      <xsl:when test="/rfc/@number">
        <xsl:value-of select="concat('urn:ietf:rfc:',/rfc/@number)"/>
      </xsl:when>
      <xsl:when test="/rfc/@docName">
        <xsl:value-of select="concat('urn:ietf:id:',/rfc/@docName)"/>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:variable>

  <package version="2.0" unique-identifier="id">
    <metadata>
      <dc:title><xsl:value-of select="rfc/front/title"/></dc:title>
      <xsl:for-each select="/rfc/front/author">
        <dc:creator><xsl:value-of select="@fullname"/></dc:creator>
      </xsl:for-each>
      <dc:language>
        <xsl:call-template name="get-lang" />
      </dc:language>
      <dc:identifier id="id"><xsl:value-of select="$uri"/></dc:identifier>
    </metadata>
    <manifest>
      <item id="doc" href="{$basename}.xhtml" media-type="application/xhtml+xml" />
      <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
      <item id="style" href="rfc2629xslt.css" media-type="text/css"/>
      <xsl:for-each select="//artwork[@type and @src]">
        <item id="artwork-{position()}" href="{@src}" media-type="{@type}"/>
      </xsl:for-each>
    </manifest>
    <spine toc="ncx">
      <itemref idref="doc"/>
    </spine>
  </package>
</xsl:template>

</xsl:transform>