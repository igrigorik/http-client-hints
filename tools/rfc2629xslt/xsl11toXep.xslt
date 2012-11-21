<!-- 
    Transform XSL 1.1 extensions to RenderX extensions

    Copyright (c) 2006, Julian Reschke (julian.reschke@greenbytes.de)
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
               xmlns:xep="http://www.renderx.com/XSL/Extensions"
               version="1.0"
>

<!-- transform bookmark elements -->

<xsl:template match="fo:bookmark-tree">
  <xep:outline>
    <xsl:apply-templates/>
  </xep:outline>
</xsl:template>

<xsl:template match="fo:bookmark" >
  <xep:bookmark internal-destination="{@internal-destination}">
    <xsl:apply-templates/>
  </xep:bookmark>
</xsl:template>

<xsl:template match="fo:bookmark-title" >
  <xep:bookmark-label>
    <xsl:apply-templates/>
  </xep:bookmark-label>
</xsl:template>

<!-- page index -->

<xsl:template match="@index-key">
  <xsl:attribute name="xep:key">
    <xsl:value-of select="."/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="fo:page-index">
  <xep:page-index>
    <xsl:apply-templates/>
  </xep:page-index>
</xsl:template>

<xsl:template match="fo:index-key-reference">
  <xep:index-item ref-key="{@ref-index-key}" merge-subsequent-page-numbers="true" link-back="true">
    <xsl:apply-templates select="@*[name()!='ref-index-key' and name()!='page-number-treatment']"/>
    <xsl:apply-templates select="*"/>
  </xep:index-item>
</xsl:template>

<xsl:template match="fo:index-range-begin">
  <xep:begin-index-range id="{@id}" xep:key="{@index-key}" />
</xsl:template>

<xsl:template match="fo:index-range-end">
  <xep:end-index-range ref-id="{@ref-id}" />
</xsl:template>

<!-- remove third-party extensions -->

<xsl:template match="*[namespace-uri()!='http://www.w3.org/1999/XSL/Format' and namespace-uri()!='http://www.renderx.com/XSL/Extensions']" />
<xsl:template match="@*[namespace-uri()!='' and namespace-uri()!='http://www.w3.org/1999/XSL/Format' and namespace-uri()!='http://www.renderx.com/XSL/Extensions']" />

<!-- rules for identity transformations -->

<xsl:template match="node()|@*"><xsl:copy><xsl:apply-templates select="node()|@*" /></xsl:copy></xsl:template>

<xsl:template match="/">
	<xsl:copy><xsl:apply-templates select="node()" /></xsl:copy>
</xsl:template>

</xsl:transform>