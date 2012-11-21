<!-- 
    Transform XSL 1.1 extensions to Apache FOP

    Copyright (c) 2007-2010, Julian Reschke (julian.reschke@greenbytes.de)
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
               xmlns:fo="http://www.w3.org/1999/XSL/Format"
               xmlns:fox="http://xmlgraphics.apache.org/fop/extensions"
               version="1.0"
>

<xsl:template match="node()|@*">
  <xsl:copy>
    <xsl:apply-templates select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="/">
	<xsl:copy><xsl:apply-templates select="node()" /></xsl:copy>
</xsl:template>

<xsl:template match="/fo:root">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()" />
    <xsl:for-each select="//@id">
      <fox:destination internal-destination="{.}"/>
    </xsl:for-each>
  </xsl:copy>
</xsl:template>

<!-- remove third-party extensions -->

<xsl:template match="*[not(ancestor::fo:declarations) and namespace-uri()!='http://www.w3.org/1999/XSL/Format' and namespace-uri()!='http://xml.apache.org/fop/extensions']" />
<xsl:template match="@*[not(ancestor::fo:declarations) and namespace-uri()!='' and namespace-uri()!='http://www.w3.org/1999/XSL/Format' and namespace-uri()!='http://xml.apache.org/fop/extensions']" />

<!-- index-page-citation-list -->

<xsl:attribute-set name="internal-link">
  <xsl:attribute name="color">#000080</xsl:attribute>
</xsl:attribute-set>

<xsl:template match="fo:index-page-citation-list">
  <xsl:variable name="items" select="fo:index-key-reference"/>
  <xsl:variable name="entries" select="//*[@index-key=$items/@ref-index-key]"/>
  <xsl:for-each select="$entries">
    <fo:basic-link internal-destination="{ancestor-or-self::*/@id}" xsl:use-attribute-sets="internal-link">
      <xsl:if test="contains(@index-key,',primary') and substring-after(@index-key,',primary')=''">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
      </xsl:if>
      <fo:page-number-citation ref-id="{ancestor-or-self::*/@id}"/>
    </fo:basic-link>
    <xsl:if test="position()!=last()"><xsl:text>, </xsl:text></xsl:if>
  </xsl:for-each>
</xsl:template>

<xsl:template match="@index-key" />
<xsl:template match="fo:index-range-end" />
<xsl:template match="fo:index-range-begin">
  <fo:block id="{@id}"/>
</xsl:template>
<xsl:template match="fo:inline[@id and @index-key and not(node())]">
  <xsl:choose>
    <xsl:when test="ancestor::fo:block">
      <fo:wrapper id="{@id}"/>
    </xsl:when>
    <xsl:otherwise>
      <fo:block id="{@id}"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:transform>