<!--
    XSLT transformation from RFC2629 XML format to NCX file format

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
               xmlns="http://www.daisy.org/z3986/2005/ncx/" 
               version="1.0"
>

<xsl:import href="rfc2629.xslt"/>

<xsl:output indent="yes" method="xml" version="1.0" encoding="UTF-8"/>
<!--<xsl:output indent="yes" method="xml" version="1.0" doctype-public="" doctype-system="ncx-2005-1.dtd"/>-->

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
      <xsl:otherwise>
        <!-- TODO -->
        <xsl:message>WARNING: no URI for document.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <ncx version="2005-1">
    <!-- add xml:lang -->
    <head>
      <meta name="dtb:uid" content="{$uri}"/>
    </head>
    <docTitle>
      <text><xsl:value-of select="/rfc/front/title"/></text>
    </docTitle>
    <xsl:for-each select="/rfc/front/author">
      <docAuthor>
        <text><xsl:value-of select="@fullname"/></text>
      </docAuthor>
    </xsl:for-each>
    <navMap>
      <xsl:apply-templates mode="ncx"/>
    </navMap>
  </ncx>
</xsl:template>

<xsl:template match="*" mode="ncx">
  <xsl:apply-templates mode="ncx"/>
</xsl:template>

<xsl:template match="section|appendix" mode="ncx">
  <xsl:variable name="no">
    <xsl:call-template name="get-section-number"/>
  </xsl:variable>
  <xsl:variable name="po">
    <xsl:number level="any" count="section|appendix"/>
  </xsl:variable>
  <navPoint id="S{$no}" playOrder="{$po}">
    <navLabel>
      <text>
        <xsl:value-of select="$no"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="@title"/>
      </text>
    </navLabel>
    <content src="{$basename}.xhtml#{$anchor-prefix}.section.{$no}"/>
    <xsl:apply-templates mode="ncx"/>
  </navPoint>
</xsl:template>

<!-- TODO: add missing stuff like references, authors section etc -->

<xsl:template match="text()" mode="ncx"/>

</xsl:transform>