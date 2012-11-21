<!--
    XSLT transformation from RFC2629 XML format to Microsoft HTML Help TOC File

    Copyright (c) 2008, Julian Reschke (julian.reschke@greenbytes.de)
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
                xmlns:exslt="http://exslt.org/common"
                xmlns:myns="mailto:julian.reschke@greenbytes.de?subject=rcf2629.xslt"
                version="1.0"
                exclude-result-prefixes="exslt myns"
>

<xsl:param name="basename" />

<xsl:include href="rfc2629.xslt" />

<xsl:output indent="yes"/>

<!-- define exslt:node-set for msxml -->       
<msxsl:script language="JScript" implements-prefix="exslt" xmlns:msxsl="urn:schemas-microsoft-com:xslt">
  this['node-set'] = function (x) {
    return x;
  }
</msxsl:script>

<xsl:template match="/" priority="9">
<html>
  <head>
    <!-- generator -->
    <meta name="generator" content="rfc2629toHhc.xslt $Id: rfc2629toHhc.xslt,v 1.14 2008-03-01 14:27:31 jre Exp $" />
  </head>
  <body>
    <object type="text/site properties">
        <param name="ImageType" value="Folder" />
        <param name="Window Styles" value="0x800025" />
    </object>
    <ul>
      <li>
        <object type="text/sitemap">
          <param name="Name" value="{/rfc/front/title}" />
          <param name="Local" value="{$basename}.html" />
        </object>
        <ul>
          <xsl:apply-templates mode="hhc" />
        </ul>
      </li>
    </ul>
  </body>
</html>
</xsl:template>

<xsl:template match="node()" mode="hhc">
  <xsl:apply-templates mode="hhc"/>
</xsl:template>

<xsl:template match="abstract" mode="hhc">
  <li>
    <object type="text/sitemap">
      <param name="Name" value="Abstract" />
      <param name="Local" value="{$basename}.html#{$anchor-prefix}.abstract" />
    </object>
  </li>
  <ul>
    <xsl:apply-templates mode="hhc"/>
  </ul>
</xsl:template>

<xsl:template match="note" mode="hhc">
  <li>
    <object type="text/sitemap">
      <param name="Name" value="{@title}" />
      <xsl:variable name="num"><xsl:number/></xsl:variable>
      <param name="Local" value="{$basename}.html#{$anchor-prefix}.note.{$num}" />
    </object>
  </li>
  <ul>
    <xsl:apply-templates mode="hhc"/>
  </ul>
</xsl:template>

<xsl:template match="section[@myns:unnumbered]" mode="hhc">
  <li>
    <object type="text/sitemap">
      <param name="Name" value="{@title}" />
      <param name="Local" value="{$basename}.html#{@anchor}" />
    </object>
  </li>
  <ul>
    <xsl:apply-templates mode="hhc"/>
  </ul>
</xsl:template>

<xsl:template match="section[not(@myns:unnumbered)]" mode="hhc">
  <xsl:variable name="sectionNumber"><xsl:call-template name="get-section-number" /></xsl:variable>
  <li>
    <object type="text/sitemap">
      <param name="Name" value="{$sectionNumber} {@title}" />
      <param name="Local" value="{$basename}.html#{$anchor-prefix}.section.{$sectionNumber}" />
    </object>
  </li>
  <ul>
    <xsl:apply-templates mode="hhc"/>
  </ul>
</xsl:template>


<xsl:template name="references-toc-hhc">

  <!-- distinguish two cases: (a) single references element (process
  as toplevel section; (b) multiple references sections (add one toplevel
  container with subsection) -->

  <xsl:variable name="number">
    <xsl:call-template name="get-references-section-number"/>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="count(/*/back/references) = 1">
      <xsl:for-each select="/*/back/references">
        <xsl:variable name="title">
          <xsl:choose>
            <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
            <xsl:otherwise>References</xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
      
        <li>
          <object type="text/sitemap">
            <param name="Name" value="{$number} {$title}" />
            <param name="Local" value="{$basename}.html#{$anchor-prefix}.references" />
          </object>
        </li>
      </xsl:for-each>
    </xsl:when>
    <xsl:otherwise>
      <!-- insert pseudo container -->    
      <li>
        <object type="text/sitemap">
          <param name="Name" value="{$number} References" />
          <param name="Local" value="{$basename}.html#{$anchor-prefix}.references" />
        </object>
        <ul>
          <!-- ...with subsections... -->    
          <xsl:for-each select="/*/back/references">
            <xsl:variable name="title">
              <xsl:choose>
                <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
                <xsl:otherwise>References</xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
          
            <xsl:variable name="sectionNumber">
              <xsl:call-template name="get-section-number" />
            </xsl:variable>
    
            <xsl:variable name="num">
              <xsl:number/>
            </xsl:variable>
    
            <li>
              <object type="text/sitemap">
                <param name="Name" value="{$sectionNumber} {$title}" />
                <param name="Local" value="{$basename}.html#{$anchor-prefix}.references.{$num}" />
              </object>
            </li>
          </xsl:for-each>
        </ul>
      </li>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="references" mode="hhc">

  <xsl:variable name="num">
    <xsl:choose>
      <xsl:when test="not(preceding::references)" />
      <xsl:otherwise>
        <xsl:text>.</xsl:text><xsl:number/>      
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="@title"><xsl:value-of select="@title" /></xsl:when>
      <xsl:otherwise>References</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <li>
    <object type="text/sitemap">
      <param name="Name" value="{$title}" />
      <param name="Local" value="{$basename}.html#{$anchor-prefix}.references{$num}" />
    </object>
  </li>

</xsl:template>

<xsl:template match="back" mode="hhc">

  <!-- <xsl:apply-templates select="references" mode="hhc" /> -->
  <xsl:apply-templates select="*[not(self::references)]" mode="hhc" />
  <xsl:apply-templates select="/rfc/front" mode="hhc" />

  <xsl:if test="not($xml2rfc-private)">
    <!-- copyright statements -->
    <li>
      <object type="text/sitemap">
        <param name="Name" value="Intellectual Property and Copyright Statements" />
        <param name="Local" value="{$basename}.html#{$anchor-prefix}.ipr" />
      </object>
    </li>
  </xsl:if>

  <!-- insert the index if index entries exist -->
  <xsl:if test="//iref">
    <li>
      <object type="text/sitemap">
        <param name="Name" value="Index" />
        <param name="Local" value="{$basename}.html#{$anchor-prefix}.index" />
      </object>
    </li>
  </xsl:if>
</xsl:template>

<xsl:template match="front" mode="hhc">

  <xsl:variable name="title">
    <xsl:if test="count(author)=1">Author's Address</xsl:if>
    <xsl:if test="count(author)!=1">Author's Addresses</xsl:if>
  </xsl:variable>

  <li>
    <object type="text/sitemap">
      <param name="Name" value="{$title}" />
      <param name="Local" value="{$basename}.html#{$anchor-prefix}.authors" />
    </object>
  </li>
</xsl:template>

<xsl:template match="rfc" mode="hhc">
  <xsl:if test="not($xml2rfc-private)">
    <!-- Get status info formatted as per RFC2629-->
    <xsl:variable name="preamble"><xsl:call-template name="insertPreamble" /></xsl:variable>

    <!-- emit it -->
    <xsl:choose>
      <xsl:when test="function-available('exslt:node-set')">
        <xsl:apply-templates select="exslt:node-set($preamble)/node()" mode="hhc"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$preamble/node()" mode="hhc"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
  
  <xsl:apply-templates select="front/abstract" mode="hhc"/>
  <xsl:apply-templates select="front/note" mode="hhc"/>

  <xsl:if test="$xml2rfc-toc">
    <bookmark xmlns="http://www.renderx.com/XSL/Extensions" internal-destination="{concat($anchor-prefix,'.toc')}">
      <bookmark-label>Table of Contents</bookmark-label>
    </bookmark>
  </xsl:if>

  <xsl:apply-templates select="middle|back" mode="hhc" />
</xsl:template>


<xsl:template match="middle" mode="hhc">

  <xsl:apply-templates mode="hhc"/>
  <xsl:call-template name="references-toc-hhc"/>
</xsl:template>

   
</xsl:transform>