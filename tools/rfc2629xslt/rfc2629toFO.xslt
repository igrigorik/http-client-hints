<!-- 
    XSLT transformation from RFC2629 XML format to XSL-FO
      
    Copyright (c) 2006-2011, Julian Reschke (julian.reschke@greenbytes.de)
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
    version="1.0"

    xmlns:ed="http://greenbytes.de/2002/rfcedit"
    xmlns:exslt="http://exslt.org/common"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt"
    xmlns:myns="mailto:julian.reschke@greenbytes.de?subject=rcf2629.xslt"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:x="http://purl.org/net/xml2rfc/ext"

    exclude-result-prefixes="ed exslt msxsl myns rdf x"
>

<xsl:import href="rfc2629.xslt" />

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no"/>

<!-- page sizes as per <http://tools.ietf.org/html/draft-rfc-editor-rfc2223bis-08#section-3.2> -->
<xsl:attribute-set name="page">
  <xsl:attribute name="margin-left">1in</xsl:attribute>
  <xsl:attribute name="margin-right">1in</xsl:attribute>
  <xsl:attribute name="page-height">11in</xsl:attribute>
  <xsl:attribute name="page-width">8.5in</xsl:attribute>
</xsl:attribute-set>

<xsl:attribute-set name="base">
  <xsl:attribute name="font-family">serif</xsl:attribute>
  <xsl:attribute name="font-size">10pt</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="h1">
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <xsl:attribute name="font-size">14pt</xsl:attribute>
  <xsl:attribute name="keep-with-next">always</xsl:attribute>
  <xsl:attribute name="space-before">14pt</xsl:attribute>
  <xsl:attribute name="space-after">7pt</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="h2">
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <xsl:attribute name="font-size">12pt</xsl:attribute>
  <xsl:attribute name="keep-with-next">always</xsl:attribute>
  <xsl:attribute name="space-before">12pt</xsl:attribute>
  <xsl:attribute name="space-after">6pt</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="h3">
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <xsl:attribute name="font-size">11pt</xsl:attribute>
  <xsl:attribute name="keep-with-next">always</xsl:attribute>
  <xsl:attribute name="space-before">11pt</xsl:attribute>
  <xsl:attribute name="space-after">3pt</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="comment">
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <xsl:attribute name="background-color">yellow</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="external-link">
  <xsl:attribute name="color">blue</xsl:attribute>
  <xsl:attribute name="text-decoration">underline</xsl:attribute>
</xsl:attribute-set>

<xsl:attribute-set name="index">
  <xsl:attribute name="font-size">9pt</xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="internal-link">
  <xsl:attribute name="color">#000080</xsl:attribute>
</xsl:attribute-set>

<xsl:attribute-set name="newpage">
  <xsl:attribute name="page-break-before">
    <xsl:choose>
      <xsl:when test="$xml2rfc-ext-duplex='yes'">right</xsl:when>
      <xsl:otherwise>always</xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:attribute-set> 

<xsl:attribute-set name="title">
  <xsl:attribute name="text-align">center</xsl:attribute>
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <xsl:attribute name="font-size">18pt</xsl:attribute>
  <xsl:attribute name="space-before">3em</xsl:attribute>
  <xsl:attribute name="space-after">3em</xsl:attribute>
</xsl:attribute-set>

<xsl:template match="abstract">
  <fo:block xsl:use-attribute-sets="h1" id="{concat($anchor-prefix,'.abstract')}">Abstract</fo:block>
  <xsl:apply-templates />
</xsl:template>

<!-- optimize empty lines starting artwork -->
<xsl:template match="artwork/text()[0=count(preceding-sibling::node())]">
  <xsl:choose>
    <xsl:when test="substring(.,1,1)='&#10;'">
      <xsl:value-of select="substring(.,2)" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="." />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="add-artwork-attr">
  <xsl:choose>
    <xsl:when test="@type='abnf' or @type='abnf2045' or @type='abnf2616' or @type='application/xml-dtd' or @type='application/relax-ng-compact-syntax'">
      <!-- just display inline -->
    </xsl:when>

    <xsl:when test="starts-with(@type,'message/http') and contains(@type,'msgtype=&quot;request&quot;')">
      <xsl:attribute name="background-color">#f0f0f0</xsl:attribute>
      <xsl:attribute name="border-style">dotted</xsl:attribute>
      <xsl:attribute name="border-width">thin</xsl:attribute>
    </xsl:when>

    <xsl:when test="starts-with(@type,'message/http')">
      <xsl:attribute name="background-color">#f8f8f8</xsl:attribute>
      <xsl:attribute name="border-style">dotted</xsl:attribute>
      <xsl:attribute name="border-width">thin</xsl:attribute>
    </xsl:when>

    <xsl:when test="starts-with(@type,'text/plain') or @type='example' or @type='code'">
      <xsl:attribute name="background-color">#f8f8f8</xsl:attribute>
      <xsl:attribute name="border-style">dotted</xsl:attribute>
      <xsl:attribute name="border-width">thin</xsl:attribute>
    </xsl:when>

    <xsl:otherwise>
      <xsl:attribute name="background-color">#dddddd</xsl:attribute>
      <xsl:attribute name="font-size">9pt</xsl:attribute>
    </xsl:otherwise>
  </xsl:choose>
  
  <xsl:choose>
    <xsl:when test="@align='center'">
      <xsl:attribute name="text-align">center</xsl:attribute>
    </xsl:when>
    <xsl:when test="@align='right'">
      <xsl:attribute name="text-align">right</xsl:attribute>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

<xsl:template match="artwork">
  <xsl:if test="@x:isCodeComponent='yes'">
    <fo:block font-family="monospace" color="gray">&lt;CODE BEGINS></fo:block>
  </xsl:if>
  <fo:block font-family="monospace" padding=".5em"
    white-space-treatment="preserve" linefeed-treatment="preserve"
    white-space-collapse="false" page-break-inside="avoid">
    <xsl:call-template name="add-artwork-attr"/>
    <xsl:apply-templates/>
  </fo:block>
  <xsl:if test="@x:isCodeComponent='yes'">
    <fo:block font-family="monospace" color="gray">&lt;CODE ENDS></fo:block>
  </xsl:if>
</xsl:template>

<xsl:template match="artwork[@src and starts-with(@type,'image/')]">
  <fo:block>
    <xsl:choose>
      <xsl:when test="@align='center'">
        <xsl:attribute name="text-align">center</xsl:attribute>
      </xsl:when>
      <xsl:when test="@align='right'">
        <xsl:attribute name="text-align">right</xsl:attribute>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
    <fo:external-graphic scaling-method="integer-pixels" src="url({@src})">
    </fo:external-graphic>
  </fo:block>
</xsl:template>

<xsl:template match="author">
  <fo:block start-indent="2em" space-before=".5em" space-after=".5em">
    <fo:block>
      <fo:wrapper font-weight="bold"><xsl:value-of select="@fullname" /></fo:wrapper>
      <xsl:if test="@role">
        <fo:wrapper> (<xsl:value-of select="@role" />)</fo:wrapper>
      </xsl:if>
      <!-- annotation support for Martin "uuml" Duerst -->
      <xsl:if test="@x:annotation">
        <xsl:text> </xsl:text> 
        <fo:wrapper font-style="italic"><xsl:value-of select="@x:annotation"/></fo:wrapper>
      </xsl:if>
    </fo:block>
    <fo:block><xsl:value-of select="organization" /></fo:block>
    <xsl:for-each select="address/postal/street">
      <fo:block><xsl:value-of select="." /></fo:block>
    </xsl:for-each>
    <xsl:if test="address/postal/city">
      <fo:block><xsl:value-of select="concat(address/postal/city,', ',address/postal/region,' ',address/postal/code)" /></fo:block>
    </xsl:if>
    <xsl:if test="address/postal/country">
      <fo:block><xsl:value-of select="address/postal/country" /></fo:block>
    </xsl:if>
    <xsl:if test="address/phone">
      <fo:block>Phone:&#0160;<fo:basic-link external-destination="url('tel:{translate(address/phone,' ','')}')" xsl:use-attribute-sets="external-link"><xsl:value-of select="address/phone" /></fo:basic-link></fo:block>
    </xsl:if>
    <xsl:if test="address/facsimile">
      <fo:block>Fax:&#0160;<fo:basic-link external-destination="url('tel:{translate(address/facsimile,' ','')}')" xsl:use-attribute-sets="external-link"><xsl:value-of select="address/facsimile" /></fo:basic-link></fo:block>
    </xsl:if>
    <xsl:for-each select="address/email">
      <xsl:variable name="email">
        <xsl:call-template name="extract-email"/>
      </xsl:variable>
      <fo:block>EMail:&#0160;
        <xsl:choose>
          <xsl:when test="$xml2rfc-linkmailto='no'">
              <xsl:value-of select="$email" />
          </xsl:when>
          <xsl:otherwise>
            <fo:basic-link external-destination="url('mailto:{$email}')" xsl:use-attribute-sets="external-link"><xsl:value-of select="$email" /></fo:basic-link>
          </xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </xsl:for-each>
    <xsl:for-each select="address/uri">
      <xsl:variable name="uri">
        <xsl:call-template name="extract-uri"/>
      </xsl:variable>
      <fo:block>
        <xsl:text>URI:&#0160;</xsl:text>
        <fo:basic-link external-destination="url('{$uri}')" xsl:use-attribute-sets="external-link"><xsl:value-of select="$uri" /></fo:basic-link>
        <xsl:if test="@x:annotation">
          <xsl:text> </xsl:text> 
          <fo:wrapper font-style="italic"><xsl:value-of select="@x:annotation"/></fo:wrapper>
        </xsl:if>
      </fo:block>
    </xsl:for-each>
  </fo:block>
</xsl:template>

<xsl:template match="back">
  <!-- done in parent template -->
</xsl:template>


<xsl:template match="figure">

  <xsl:variable name="anch">
    <xsl:call-template name="get-figure-anchor"/>
  </xsl:variable>

  <fo:block space-before=".5em" space-after=".5em" id="{$anch}" page-break-inside="avoid">
    <xsl:if test="not(ancestor::t)">
      <xsl:attribute name="start-indent">2em</xsl:attribute>
    </xsl:if>
    <xsl:call-template name="add-anchor"/>
    <xsl:apply-templates />
    <xsl:if test="(@title!='' or @anchor!='') and not(@suppress-title='true')">
      <xsl:variable name="n"><xsl:number level="any" count="figure[(@title!='' or @anchor!='') and not(@suppress-title='true')]" /></xsl:variable>
      <fo:block text-align="center" space-before=".5em" space-after="1em">Figure <xsl:value-of select="$n"/><xsl:if test="@title!=''">: <xsl:value-of select="@title" /></xsl:if></fo:block>
    </xsl:if>
  </fo:block>
</xsl:template>
            
<xsl:template match="front">

  <xsl:if test="$xml2rfc-topblock!='no'">
    <!-- collect information for left column -->
      
    <xsl:variable name="leftColumn">
      <xsl:call-template name="collectLeftHeaderColumn" />  
    </xsl:variable>
  
    <!-- collect information for right column -->
      
    <xsl:variable name="rightColumn">
      <xsl:call-template name="collectRightHeaderColumn" />    
    </xsl:variable>
      
      <!-- insert the collected information -->
      
    <fo:table width="100%" table-layout="fixed">
      <fo:table-column column-width="proportional-column-width(1)" />
      <fo:table-column column-width="proportional-column-width(1)" />
      <fo:table-body>
        <xsl:choose>
          <xsl:when test="function-available('exslt:node-set')">
             <xsl:call-template name="emitheader">
               <xsl:with-param name="lc" select="exslt:node-set($leftColumn)" />    
               <xsl:with-param name="rc" select="exslt:node-set($rightColumn)" />    
            </xsl:call-template>
          </xsl:when>    
          <xsl:otherwise>    
             <xsl:call-template name="emitheader">
               <xsl:with-param name="lc" select="$leftColumn" />    
               <xsl:with-param name="rc" select="$rightColumn" />    
            </xsl:call-template>
          </xsl:otherwise>    
        </xsl:choose>
      </fo:table-body>
    </fo:table>
  </xsl:if>
      
  <fo:block xsl:use-attribute-sets="title">
    <xsl:apply-templates select="/rfc/front/title" mode="get-text-content" />
    <xsl:if test="/rfc/@docName">
      <fo:block font-size="80%"><xsl:value-of select="/rfc/@docName" /></fo:block>
    </xsl:if>
  </fo:block>
 
  <xsl:if test="$xml2rfc-private='' and not($abstract-first)">
    <xsl:call-template name="emit-ietf-preamble"/>
  </xsl:if>
  
  <xsl:apply-templates select="x:boilerplate"/>
  <xsl:apply-templates select="abstract" />
  <xsl:apply-templates select="note[@title!='IESG Note' or $xml2rfc-private!='']" />

  <xsl:if test="$xml2rfc-private='' and $abstract-first">
    <xsl:call-template name="emit-ietf-preamble"/>
  </xsl:if>

  <xsl:if test="$xml2rfc-toc='yes'">
    <xsl:apply-templates select="/" mode="toc" />
    <!--<xsl:call-template name="insertTocAppendix" />-->
  </xsl:if>

</xsl:template>
   
<xsl:template match="eref[node()]">
  <fo:basic-link external-destination="url('{@target}')" xsl:use-attribute-sets="external-link">
    <xsl:call-template name="format-uri">
      <xsl:with-param name="s" select="."/>
    </xsl:call-template>
  </fo:basic-link>
  <fo:footnote>
    <fo:inline font-size="6pt" vertical-align="super"><xsl:number level="any" count="eref[node()]" /></fo:inline>
    <fo:footnote-body>
      <fo:block font-size="8pt" start-indent="2em" text-align="left">
        <fo:inline font-size="6pt" vertical-align="super"><xsl:number level="any" count="eref[node()]" /></fo:inline>
        <xsl:text> </xsl:text>
        <xsl:value-of select="@target" />
      </fo:block>
    </fo:footnote-body>
  </fo:footnote>
</xsl:template>

<xsl:template match="eref[not(node())]">
  <xsl:text>&lt;</xsl:text>
  <fo:basic-link external-destination="url('{@target}')" xsl:use-attribute-sets="external-link">
    <xsl:call-template name="format-uri">
      <xsl:with-param name="s" select="@target"/>
    </xsl:call-template>
  </fo:basic-link>
  <xsl:text>&gt;</xsl:text>
</xsl:template>

<!-- processed in a later stage -->
<xsl:template match="iref[not(ancestor::t) and not(parent::section)]">
  <fo:block>
    <xsl:attribute name="id"><xsl:value-of select="$anchor-prefix" />.iref.<xsl:number level="any"/></xsl:attribute>
    <xsl:choose>
      <xsl:when test="@primary='true'">
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem,',primary')"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem)"/>
        </xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </fo:block>
</xsl:template>

<xsl:template match="iref[parent::section]">
  <!-- processed on section level -->
</xsl:template>

<xsl:template match="iref[ancestor::t and not(parent::section)]">
  <fo:inline>
    <xsl:attribute name="id"><xsl:value-of select="$anchor-prefix" />.iref.<xsl:number level="any"/></xsl:attribute>
    <xsl:choose>
      <xsl:when test="@primary='true'">
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem,',primary')"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem)"/>
        </xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </fo:inline>
</xsl:template>

<xsl:template match="iref" mode="iref-start">
  <fo:index-range-begin>
    <xsl:attribute name="id"><xsl:value-of select="$anchor-prefix" />.iref.<xsl:number level="any"/></xsl:attribute>
    <xsl:choose>
      <xsl:when test="@primary='true'">
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem,',primary')"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="index-key">
          <xsl:value-of select="concat('item=',@item,',subitem=',@subitem)"/>
        </xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </fo:index-range-begin>
</xsl:template>

<xsl:template match="iref" mode="iref-end">
  <fo:index-range-end>
    <xsl:attribute name="ref-id"><xsl:value-of select="$anchor-prefix" />.iref.<xsl:number level="any"/></xsl:attribute>
  </fo:index-range-end>
</xsl:template>

<xsl:template match="list[@style='hanging']" priority="1">

  <xsl:variable name="width">
    <xsl:choose>
      <xsl:when test="@x:indent">
        <xsl:value-of select="@x:indent"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- find longest label and use it to calculate indentation-->
        <xsl:variable name="l">
          <xsl:for-each select="t">
            <xsl:sort select="string-length(@hangText)" order="descending" data-type="number"/>
            <xsl:if test="position()=1">
              <xsl:value-of select="@hangText" />
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="concat(format-number(string-length($l) * 0.8, '#.0'),'em')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <fo:list-block provisional-distance-between-starts="{$width}">
    <xsl:apply-templates />
  </fo:list-block>
</xsl:template>

<xsl:template match="list[@style='hanging']/x:lt" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block><xsl:value-of select="@hangText" /></fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()">
      <xsl:for-each select="t">
        <fo:block>
          <xsl:if test="position()!=1">
            <xsl:attribute name="space-before">.25em</xsl:attribute>
          </xsl:if>
          <xsl:apply-templates />
        </fo:block>
      </xsl:for-each>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[@style='hanging']/t | list[@style='hanging']/ed:replace/ed:ins/t" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block><xsl:value-of select="@hangText" /></fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()"><fo:block><xsl:apply-templates /></fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[@style='symbols']" priority="1">
  <fo:list-block provisional-distance-between-starts="1.5em">
    <xsl:apply-templates />
  </fo:list-block>
</xsl:template>

<xsl:template match="list[@style='symbols']/t" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block>&#x2022;</fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()"><fo:block><xsl:apply-templates /></fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[@style='symbols']/x:lt" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block>&#x2022;</fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()">
      <xsl:for-each select="t">
        <fo:block>
          <xsl:if test="position()!=1">
            <xsl:attribute name="space-before">.25em</xsl:attribute>
          </xsl:if>
          <xsl:apply-templates />
        </fo:block>
      </xsl:for-each>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list">
  <xsl:if test="@style!='' and @style!='empty' and @style">
    <xsl:call-template name="warning">
      <xsl:with-param name="msg">unknown style '<xsl:value-of select="@style"/>' for list, continueing with default format.</xsl:with-param>
    </xsl:call-template>
  </xsl:if>
  <fo:list-block provisional-distance-between-starts="2em">
    <xsl:apply-templates />
  </fo:list-block>
</xsl:template>

<xsl:template match="list/t">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block></fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()"><fo:block><xsl:apply-templates /></fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[@style='numbers' or @style='letters']" priority="1">
  <fo:list-block provisional-distance-between-starts="1.5em">
    <xsl:apply-templates />
  </fo:list-block>
</xsl:template>

<xsl:template match="list[@style='numbers' or @style='letters']/t" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()">
      <fo:block>
        <xsl:choose>
          <xsl:when test="ancestor::list/@style='numbers'"><xsl:number/>.</xsl:when>
          <xsl:when test="ancestor::list/@style='letters'"><xsl:number format="a"/>.</xsl:when>
          <xsl:otherwise>???</xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body start-indent="body-start()"><fo:block><xsl:apply-templates /></fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[@style='numbers' or @style='letters']/x:lt" priority="1">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()">
      <fo:block>
        <xsl:choose>
          <xsl:when test="ancestor::list/@style='numbers'"><xsl:number/>.</xsl:when>
          <xsl:when test="ancestor::list/@style='letters'"><xsl:number format="a"/>.</xsl:when>
          <xsl:otherwise>???</xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body start-indent="body-start()">
      <xsl:for-each select="t">
        <fo:block>
          <xsl:if test="position()!=1">
            <xsl:attribute name="space-before">.25em</xsl:attribute>
          </xsl:if>
          <xsl:apply-templates />
        </fo:block>
      </xsl:for-each>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<!-- special case: nested -->
<xsl:template match="list//t//list[@style='letters']/t" priority="9">
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()"><fo:block><xsl:number format="A"/>.</fo:block></fo:list-item-label>
    <fo:list-item-body start-indent="body-start()"><fo:block><xsl:apply-templates /></fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="list[starts-with(@style,'format ')]" priority="1">
  <fo:list-block provisional-distance-between-starts="{string-length(@style) - string-length('format ')}em">
    <xsl:apply-templates />
  </fo:list-block>
</xsl:template>

<xsl:template match="list[starts-with(@style,'format ') and (contains(@style,'%c') or contains(@style,'%d'))]/t" priority="1">
  <xsl:variable name="list" select=".." />
  <xsl:variable name="format" select="substring-after(../@style,'format ')" />
  <xsl:variable name="pos">
    <xsl:choose>
      <xsl:when test="$list/@counter">
        <xsl:number level="any" count="list[@counter=$list/@counter or (not(@counter) and @style=concat('format ',$list/@counter))]/t" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:number level="any" count="list[concat('format ',@counter)=$list/@style or (not(@counter) and @style=$list/@style)]/t" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <fo:list-item space-before=".25em" space-after=".25em">
    <xsl:call-template name="copy-anchor"/>
    <fo:list-item-label end-indent="label-end()">
      <fo:block>
        <xsl:choose>
          <xsl:when test="contains($format,'%c')">
            <xsl:value-of select="substring-before($format,'%c')"/><xsl:number value="$pos" format="a" /><xsl:value-of select="substring-after($format,'%c')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="substring-before($format,'%d')"/><xsl:number value="$pos" format="1" /><xsl:value-of select="substring-after($format,'%d')"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body start-indent="body-start()">
      <fo:block>
        <xsl:apply-templates />
      </fo:block>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="middle">
  <xsl:apply-templates />
</xsl:template>
               
<xsl:template match="note">
  <xsl:variable name="num"><xsl:number count="note"/></xsl:variable>
  <fo:block xsl:use-attribute-sets="h1" id="{concat($anchor-prefix,'.note.',$num)}"><xsl:value-of select="@title" /></fo:block>
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="preamble">
  <fo:block space-after=".5em">
    <xsl:call-template name="copy-anchor"/>
    <xsl:apply-templates />
  </fo:block>
</xsl:template>

<xsl:template match="postamble">
  <fo:block space-before=".5em"><xsl:apply-templates /></fo:block>
</xsl:template>

<xsl:template match="reference">

  <xsl:variable name="target">
    <xsl:choose>
      <xsl:when test="@target"><xsl:value-of select="@target" /></xsl:when>
      <xsl:when test="seriesInfo/@name='RFC'"><xsl:value-of select="concat($rfcUrlPrefix,seriesInfo[@name='RFC']/@value,'.txt')" /></xsl:when>
      <xsl:when test="seriesInfo[starts-with(.,'RFC')]">
        <xsl:variable name="rfcRef" select="seriesInfo[starts-with(.,'RFC')]" />
        <xsl:value-of select="concat($rfcUrlPrefix,substring-after (normalize-space($rfcRef), ' '),'.txt')" />
      </xsl:when>
      <xsl:otherwise />
    </xsl:choose>
  </xsl:variable>

  <fo:list-item space-after=".5em">
    <fo:list-item-label end-indent="label-end()">
      <fo:block id="{@anchor}">
        <xsl:if test="$xml2rfc-ext-include-references-in-index='yes'">
          <xsl:attribute name="index-key">
            <xsl:value-of select="concat('xrefitem=',@anchor)"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:call-template name="referencename">
          <xsl:with-param name="node" select="." />
        </xsl:call-template>
      </fo:block>
    </fo:list-item-label>
    
    <fo:list-item-body start-indent="body-start()"><fo:block>

      <xsl:for-each select="front/author">
        <xsl:variable name="initials">
          <xsl:call-template name="format-initials"/>
        </xsl:variable>
        <xsl:variable name="truncated-initials" select="concat(substring-before($initials,'.'),'.')"/>
        <xsl:choose>
          <xsl:when test="@surname and @surname!=''">
            <xsl:choose>
              <xsl:when test="@surname and position()=last() and position()!=1">
                <xsl:value-of select="concat($truncated-initials,' ',@surname)" />
              </xsl:when>
              <xsl:when test="@surname">
                <xsl:value-of select="concat(@surname,', ',$truncated-initials)" />
              </xsl:when>
              <xsl:when test="organization/text()">
                <xsl:value-of select="organization" />
              </xsl:when>
              <xsl:otherwise />
            </xsl:choose>
            <xsl:if test="@role='editor'">
              <xsl:text>, Ed.</xsl:text>
            </xsl:if>
            <xsl:choose>
              <xsl:when test="position()=last() - 1">
                <xsl:if test="last() &gt; 2">,</xsl:if>
                <xsl:text> and </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>, </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:when test="organization/text()">
            <xsl:value-of select="organization" />
            <xsl:choose>
              <xsl:when test="position()=last() - 1">
                <xsl:if test="last() &gt; 2">,</xsl:if>
                <xsl:text> and </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>, </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise />
        </xsl:choose>
      </xsl:for-each>

      <xsl:if test="not(front/title/@x:quotes='false')">"<!--&#8220;--></xsl:if>
      <xsl:choose>
        <xsl:when test="string-length($target) &gt; 0">
          <fo:basic-link external-destination="url('{$target}')" xsl:use-attribute-sets="external-link"><xsl:value-of select="normalize-space(front/title)" /></fo:basic-link>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(front/title)" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="not(front/title/@x:quotes='false')">"<!--&#8221;--></xsl:if>
      
      <xsl:for-each select="seriesInfo">
        <xsl:text>, </xsl:text>
        <xsl:choose>
          <xsl:when test="not(@name) and not(@value) and ./text()"><xsl:value-of select="." /></xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@name" />
            <xsl:if test="@value!=''">&#0160;<xsl:value-of select="@value" /></xsl:if>
            <xsl:if test="translate(@name,$ucase,$lcase)='internet-draft'"> (work in progress)</xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>

      <!-- avoid hacks using seriesInfo when it's not really series information -->
      <xsl:for-each select="x:prose">
        <xsl:text>, </xsl:text>
        <xsl:value-of select="."/>
      </xsl:for-each>

      <xsl:if test="front/date/@year!=''">
        <xsl:text>, </xsl:text>
        <xsl:value-of select="front/date/@month" />&#0160;<xsl:value-of select="front/date/@year" />
      </xsl:if>
      
      <xsl:if test="@target">
        <xsl:text>, &lt;</xsl:text>
        <xsl:call-template name="format-uri">
          <xsl:with-param name="s" select="@target"/>
        </xsl:call-template>
        <xsl:text>&gt;</xsl:text>
      </xsl:if>

      <xsl:text>.</xsl:text>
      
      <xsl:for-each select="annotation">
        <fo:block><xsl:apply-templates /></fo:block>
      </xsl:for-each>
      
    </fo:block></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="references">

  <xsl:variable name="name">
    <xsl:number/>      
  </xsl:variable>

  <!-- insert pseudo section when needed -->
  <xsl:if test="$name='1' and count(/*/back/references)!=1">
    <fo:block id="{$anchor-prefix}.references" xsl:use-attribute-sets="h1">
      <xsl:if test="$name='1'">
        <xsl:attribute name="page-break-before">always</xsl:attribute>
      </xsl:if>
      <xsl:variable name="sectionNumber">
        <xsl:call-template name="get-references-section-number"/>
      </xsl:variable>
      <xsl:call-template name="emit-section-number">
        <xsl:with-param name="no" select="$sectionNumber"/>
      </xsl:call-template>
      <xsl:text>&#160;&#160;</xsl:text>
      <xsl:value-of select="$xml2rfc-refparent"/>
    </fo:block>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="count(/*/back/references)=1">
      <fo:block id="{$anchor-prefix}.references" xsl:use-attribute-sets="h1 newpage">
        <xsl:variable name="sectionNumber">
          <xsl:call-template name="get-section-number"/>
        </xsl:variable>
        <xsl:call-template name="emit-section-number">
          <xsl:with-param name="no" select="$sectionNumber"/>
        </xsl:call-template>
        <xsl:text>&#160;&#160;</xsl:text>
        <xsl:choose>
          <xsl:when test="@title!=''"><xsl:value-of select="@title"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </xsl:when>
    <xsl:otherwise>
      <fo:block id="{$anchor-prefix}.references.{$name}" xsl:use-attribute-sets="h2">
        <xsl:variable name="sectionNumber">
          <xsl:call-template name="get-section-number"/>
        </xsl:variable>
        <xsl:call-template name="emit-section-number">
          <xsl:with-param name="no" select="$sectionNumber"/>
        </xsl:call-template>
        <xsl:text>&#160;&#160;</xsl:text>
        <xsl:choose>
          <xsl:when test="@title!=''"><xsl:value-of select="@title"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
        </xsl:choose>
      </fo:block>
    </xsl:otherwise>
  </xsl:choose>

  <!-- find longest label and use it to calculate indentation-->
  <xsl:variable name="l">
    <xsl:choose>
      <xsl:when test="$xml2rfc-symrefs='no'">[99]</xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="//reference">
          <xsl:sort select="string-length(@anchor)" order="descending" data-type="number"/>
          <xsl:if test="position()=1">
            <xsl:value-of select="@anchor" />
          </xsl:if>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <fo:list-block provisional-distance-between-starts="{string-length($l) * 0.8}em">
    <xsl:choose>
      <xsl:when test="$xml2rfc-sortrefs='yes'">
        <xsl:apply-templates>
          <xsl:sort select="@anchor" />
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates />
      </xsl:otherwise>
    </xsl:choose>
  </fo:list-block>
</xsl:template>

<xsl:template match="rfc">
  <fo:root xsl:use-attribute-sets="base">
    
    <fo:layout-master-set>
      <fo:simple-page-master master-name="first-page" xsl:use-attribute-sets="page">
        <fo:region-body margin-bottom="1in" margin-top="1in"/>
         <fo:region-after extent="1cm" region-name="footer"/>
      </fo:simple-page-master>
      <fo:simple-page-master master-name="other-pages-right" xsl:use-attribute-sets="page">
        <fo:region-body margin-bottom="1in" margin-top="1in" />
        <fo:region-before extent="1cm" region-name="header-right"/>
        <fo:region-after extent="1cm" region-name="footer-right"/>
      </fo:simple-page-master>
      <fo:simple-page-master master-name="other-pages-left" xsl:use-attribute-sets="page">
        <fo:region-body margin-bottom="1in" margin-top="1in" />
        <fo:region-before extent="1cm" region-name="header-left"/>
        <fo:region-after extent="1cm" region-name="footer-left"/>
      </fo:simple-page-master>
      <fo:simple-page-master master-name="other-pages-dc-right" xsl:use-attribute-sets="page">
        <fo:region-body margin-bottom="1in" margin-top="1in" column-count="2"/>
        <fo:region-before extent="1cm" region-name="header-right"/>
        <fo:region-after extent="1cm" region-name="footer-right"/>
      </fo:simple-page-master>
      <fo:simple-page-master master-name="other-pages-dc-left" xsl:use-attribute-sets="page">
        <fo:region-body margin-bottom="1in" margin-top="1in" column-count="2"/>
        <fo:region-before extent="1cm" region-name="header-left"/>
        <fo:region-after extent="1cm" region-name="footer-left"/>
      </fo:simple-page-master>
      <fo:page-sequence-master master-name="sequence">  
        <fo:single-page-master-reference master-reference="first-page" />
        <xsl:choose>
          <xsl:when test="$xml2rfc-ext-duplex='yes'">
            <fo:repeatable-page-master-alternatives>
              <fo:conditional-page-master-reference odd-or-even="even" master-reference="other-pages-left"/>
              <fo:conditional-page-master-reference odd-or-even="odd" master-reference="other-pages-right"/>
            </fo:repeatable-page-master-alternatives>
          </xsl:when>
          <xsl:otherwise>
            <fo:repeatable-page-master-reference master-reference="other-pages-right" />  
          </xsl:otherwise>
        </xsl:choose>
      </fo:page-sequence-master> 
      <fo:page-sequence-master master-name="sequence-dc">  
        <xsl:choose>
          <xsl:when test="$xml2rfc-ext-duplex='yes'">
            <fo:repeatable-page-master-alternatives>
              <fo:conditional-page-master-reference odd-or-even="even" master-reference="other-pages-dc-left"/>
              <fo:conditional-page-master-reference odd-or-even="odd" master-reference="other-pages-dc-right"/>
            </fo:repeatable-page-master-alternatives>
          </xsl:when>
          <xsl:otherwise>
            <fo:repeatable-page-master-reference master-reference="other-pages-dc-right" />  
          </xsl:otherwise>
        </xsl:choose>
      </fo:page-sequence-master> 
    </fo:layout-master-set>

    <fo:declarations>
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title><xsl:value-of select="/rfc/front/title"/></dc:title>
          <dc:creator><xsl:call-template name="get-author-summary" /></dc:creator>
          <dc:description><xsl:value-of select="normalize-space(/rfc/front/abstract)"/></dc:description>
          <xsl:if test="/rfc/@number">
            <dc:isPartOf>urn:ISSN:2070-1721</dc:isPartOf>
          </xsl:if>      
          <xsl:if test="/rfc/front/keyword" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
            <pdf:Keywords>
              <xsl:for-each select="/rfc/front/keyword">
                <xsl:value-of select="."/>
                <xsl:if test="position()!=last()">, </xsl:if>
              </xsl:for-each>
            </pdf:Keywords>
          </xsl:if>
        </rdf:Description>
      </rdf:RDF>
    </fo:declarations>
    
    <fo:bookmark-tree>
      <xsl:apply-templates select="." mode="bookmarks" />
    </fo:bookmark-tree>

    <xsl:variable name="lang"><xsl:call-template name="get-lang"/></xsl:variable>

    <fo:page-sequence master-reference="sequence" language="{$lang}">
      <xsl:if test="$xml2rfc-ext-duplex='yes'">
        <xsl:attribute name="force-page-count">even</xsl:attribute>
      </xsl:if>

      <xsl:call-template name="insertHeader" />
      <xsl:call-template name="insertFooter" />
     
      <fo:flow flow-name="xsl-region-body">
        
        <!-- process front & middle section, but not back -->
        <xsl:apply-templates />
        
        <!-- because it requires multiple page masters -->
        <!-- references first -->
        <xsl:apply-templates select="back/references" />
        
        <xsl:if test="$xml2rfc-ext-authors-section!='end'">
          <xsl:call-template name="insertAuthors" />
        </xsl:if>
        
        <!-- add all other top-level sections under <back> -->
        <xsl:apply-templates select="back/*[not(self::references)]" />
      
      </fo:flow>
    </fo:page-sequence>
    
    <xsl:if test="$has-index">
      <fo:page-sequence master-reference="sequence-dc" language="{$lang}">
        <xsl:if test="$xml2rfc-ext-duplex='yes'">
          <xsl:attribute name="force-page-count">even</xsl:attribute>
        </xsl:if>
        <xsl:call-template name="insertHeader" />
        <xsl:call-template name="insertFooter" />
        <fo:flow flow-name="xsl-region-body" xsl:use-attribute-sets="index">
          <xsl:call-template name="insertIndex" />    
        </fo:flow>
      </fo:page-sequence>
    </xsl:if>

    <xsl:if test="$xml2rfc-ext-authors-section='end' or ($xml2rfc-private='' and not($no-copylong))">
      <fo:page-sequence master-reference="sequence" language="{$lang}">
        <xsl:if test="$xml2rfc-ext-duplex='yes'">
          <xsl:attribute name="force-page-count">even</xsl:attribute>
        </xsl:if>
  
        <xsl:call-template name="insertHeader" />
        <xsl:call-template name="insertFooter" />
       
        <fo:flow flow-name="xsl-region-body">
          
          <xsl:if test="$xml2rfc-ext-authors-section='end'">
            <xsl:call-template name="insertAuthors" />
          </xsl:if>
  
          <xsl:if test="$xml2rfc-private=''">
            <!-- copyright statements -->
            <xsl:variable name="copyright">
              <xsl:call-template name="insertCopyright" />
            </xsl:variable>
          
            <!-- emit it -->
            <xsl:choose>
              <xsl:when test="function-available('exslt:node-set')">
                <xsl:apply-templates select="exslt:node-set($copyright)/node()" />
              </xsl:when>
              <xsl:otherwise> <!--proceed with fingers crossed-->
                <xsl:variable name="temp" select="$copyright"/>
                <xsl:apply-templates select="$temp/node()" />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:if>
          
        </fo:flow>
      </fo:page-sequence>
    </xsl:if>
    
  </fo:root>
</xsl:template>


<xsl:template name="section-maker">
  <xsl:variable name="sectionNumber">
    <xsl:choose>
      <xsl:when test="@myns:unnumbered"></xsl:when>
      <xsl:when test="ancestor::x:boilerplate"></xsl:when>
      <xsl:otherwise><xsl:call-template name="get-section-number" /></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="$sectionNumber!=''">
    <xsl:attribute name="id"><xsl:value-of select="concat($anchor-prefix,'.section.',$sectionNumber)"/>
  </xsl:attribute></xsl:if>
  
  <xsl:call-template name="add-anchor" />
  
  <xsl:if test="$sectionNumber!='' and not(contains($sectionNumber,'unnumbered-'))">
    <xsl:call-template name="emit-section-number">
      <xsl:with-param name="no" select="$sectionNumber"/>
    </xsl:call-template>
    <xsl:text>&#0160;&#0160;</xsl:text>
  </xsl:if>
  <xsl:value-of select="@title" />

</xsl:template>

<xsl:template match="section[count(ancestor::section) = 0 and (@myns:notoclink or ancestor::x:boilerplate)]">

  <fo:block xsl:use-attribute-sets="h1">
    <xsl:call-template name="section-maker" />
  </fo:block>

  <xsl:apply-templates select="iref" mode="iref-start"/>
  <xsl:apply-templates />
  <xsl:apply-templates select="iref" mode="iref-end"/>
</xsl:template>

<xsl:template match="section[count(ancestor::section) = 0 and not(@myns:notoclink or ancestor::x:boilerplate)]">

  <fo:block xsl:use-attribute-sets="h1 newpage">
    <xsl:call-template name="section-maker" />
  </fo:block>

  <xsl:apply-templates select="iref" mode="iref-start"/>
  <xsl:apply-templates />
  <xsl:apply-templates select="iref" mode="iref-end"/>
</xsl:template>

<xsl:template match="section[count(ancestor::section) = 1]">
  <fo:block xsl:use-attribute-sets="h2">
    <xsl:call-template name="section-maker" />
  </fo:block>

  <xsl:apply-templates select="iref" mode="iref-start"/>
  <xsl:apply-templates />
  <xsl:apply-templates select="iref" mode="iref-end"/>
</xsl:template>

<xsl:template match="section[count(ancestor::section) &gt; 1]">
  <fo:block xsl:use-attribute-sets="h3">
    <xsl:call-template name="section-maker" />
  </fo:block>

  <xsl:apply-templates select="iref" mode="iref-start"/>
  <xsl:apply-templates />
  <xsl:apply-templates select="iref" mode="iref-end"/>
</xsl:template>

<xsl:template match="spanx[@style='emph' or not(@style)]">
  <fo:wrapper font-style="italic">
    <xsl:call-template name="copy-anchor"/>
    <xsl:apply-templates />
  </fo:wrapper>
</xsl:template>

<xsl:template match="spanx[@style='strong']">
  <fo:wrapper font-weight="bold">
    <xsl:call-template name="copy-anchor"/>
    <xsl:apply-templates />
  </fo:wrapper>
</xsl:template>

<xsl:template match="spanx[@style='verb']">
  <fo:wrapper font-family="monospace">
    <xsl:call-template name="copy-anchor"/>
    <xsl:apply-templates/>
  </fo:wrapper>
</xsl:template>

<xsl:template match="t">
  <fo:block space-before=".5em" space-after=".5em">
    <xsl:call-template name="insert-justification"/>
    <xsl:choose>
      <xsl:when test="parent::x:blockquote">
        <xsl:attribute name="start-indent">4em</xsl:attribute>
      </xsl:when>
      <xsl:when test="parent::x:note">
        <xsl:attribute name="start-indent">4em</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="start-indent">2em</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="copy-anchor"/>
    <xsl:apply-templates />
  </fo:block>
</xsl:template>
               
<xsl:template match="vspace">
  <fo:block/>
</xsl:template>

<xsl:template name="render-section-ref">
  <xsl:param name="from" />
  <xsl:param name="to" />
  <xsl:variable name="target" select="$from/@target" />

  <xsl:variable name="refname">
    <xsl:for-each select="$to">
      <xsl:call-template name="get-section-type">
        <xsl:with-param name="prec" select="$from/preceding-sibling::node()[1]" />
      </xsl:call-template>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="refnum">
    <xsl:for-each select="$to">
      <xsl:call-template name="get-section-number" />
    </xsl:for-each>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="@format='counter'">
      <xsl:value-of select="$refnum"/>
    </xsl:when>
    <xsl:when test="@format='title'">
      <xsl:value-of select="$to/@title"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="normalize-space(concat($refname,'&#160;',$refnum))"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="xref[node()]">
  <xsl:variable name="target" select="@target" />
  <xsl:variable name="node" select="//*[@anchor=$target]" />
  <xsl:variable name="anchor"><xsl:value-of select="$anchor-prefix"/>.xref.<xsl:value-of select="@target"/>.<xsl:number level="any" count="xref[@target=$target]"/></xsl:variable>
  <xsl:choose>
    <xsl:when test="@x:fmt='none'">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:if test="$node/self::reference and $xml2rfc-ext-include-references-in-index='yes'">
          <xsl:attribute name="id">
            <xsl:value-of select="$anchor"/>
          </xsl:attribute>
          <xsl:attribute name="index-key">
            <xsl:value-of select="concat('xrefitem=',@target)"/>
          </xsl:attribute>
        </xsl:if>
        <!-- insert id when a backlink to this xref is needed in the index -->
        <xsl:variable name="ireftargets" select="//iref[@x:for-anchor=$target] | //iref[@x:for-anchor='' and ../@anchor=$target]"/>
        <xsl:if test="$ireftargets">
          <xsl:attribute name="id"><xsl:value-of select="$anchor"/></xsl:attribute>
        </xsl:if>
        <xsl:for-each select="$ireftargets">
          <fo:wrapper index-key="{concat('item=',@item,',subitem=',@subitem)}" />
        </xsl:for-each>
        <xsl:apply-templates/>
      </fo:basic-link>
    </xsl:when>
    
    <xsl:when test="$node/self::section or $node/self::appendix">
      <xsl:choose>
        <xsl:when test="@format='none'">
          <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
            <!-- insert id when a backlink to this xref is needed in the index -->
            <xsl:variable name="ireftargets" select="//iref[@x:for-anchor=$target] | //iref[@x:for-anchor='' and ../@anchor=$target]"/>
            <xsl:if test="$ireftargets">
              <xsl:attribute name="id"><xsl:value-of select="$anchor"/></xsl:attribute>
            </xsl:if>
            <xsl:for-each select="$ireftargets">
              <fo:wrapper index-key="{concat('item=',@item,',subitem=',@subitem)}" />
            </xsl:for-each>
            <xsl:apply-templates/>
          </fo:basic-link>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
          <xsl:text> (</xsl:text>
          <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
            <!-- insert id when a backlink to this xref is needed in the index -->
            <xsl:variable name="ireftargets" select="//iref[@x:for-anchor=$target] | //iref[@x:for-anchor='' and ../@anchor=$target]"/>
            <xsl:if test="$ireftargets">
              <xsl:attribute name="id"><xsl:value-of select="$anchor"/></xsl:attribute>
            </xsl:if>
            <xsl:for-each select="$ireftargets">
              <fo:wrapper index-key="{concat('item=',@item,',subitem=',@subitem)}" />
            </xsl:for-each>
            <xsl:call-template name="render-section-ref">
              <xsl:with-param name="from" select="."/>
              <xsl:with-param name="to" select="$node"/>
            </xsl:call-template>
          </fo:basic-link>
          <xsl:text>)</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    
    <xsl:otherwise>
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:value-of select="." />
      </fo:basic-link>
      <xsl:if test="not(@format='none')">
        <xsl:for-each select="//reference[@anchor=$target]">
          &#160;<xsl:call-template name="referencename"><xsl:with-param name="node" select="." /></xsl:call-template>
        </xsl:for-each>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>

<xsl:template match="xref[not(node())]">

  <xsl:variable name="target" select="@target" />
  <xsl:variable name="anchor"><xsl:value-of select="$anchor-prefix"/>.xref.<xsl:value-of select="@target"/>.<xsl:number level="any" count="xref[@target=$target]"/></xsl:variable>
  <xsl:variable name="node" select="//*[@anchor=$target]" />
  <xsl:if test="count($node)=0 and not(ancestor::ed:del)">
    <xsl:message>Undefined target: <xsl:value-of select="@target" /></xsl:message>
    <span class="error">Undefined target: <xsl:value-of select="@target" /></span>
  </xsl:if>

  <xsl:choose>

    <!-- Section links -->
    <xsl:when test="$node/self::section or $node/self::appendix">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <!-- insert id when a backlink to this xref is needed in the index -->
        <xsl:variable name="ireftargets" select="//iref[@x:for-anchor=$target] | //iref[@x:for-anchor='' and ../@anchor=$target]"/>
        <xsl:if test="$ireftargets">
          <xsl:attribute name="id"><xsl:value-of select="$anchor"/></xsl:attribute>
        </xsl:if>
        <xsl:for-each select="$ireftargets">
          <fo:wrapper index-key="{concat('item=',@item,',subitem=',@subitem)}" />
        </xsl:for-each>
        <xsl:call-template name="render-section-ref">
          <xsl:with-param name="from" select="."/>
          <xsl:with-param name="to" select="$node"/>
        </xsl:call-template>
      </fo:basic-link>
    </xsl:when>

    <!-- Figure links -->
    <xsl:when test="$node//self::figure">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:variable name="figcnt">
          <xsl:for-each select="$node">
            <xsl:number level="any" count="figure[(@title!='' or @anchor!='') and not(@suppress-title='true')]" />
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="@format='counter'">
            <xsl:value-of select="$figcnt" />
          </xsl:when>
          <xsl:when test="@format='title'">
            <xsl:value-of select="$node/@title" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(concat('Figure&#160;',$figcnt))"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:basic-link>
    </xsl:when>

    <!-- Table links -->
    <xsl:when test="$node/self::texttable">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:variable name="tabcnt">
          <xsl:for-each select="$node">
            <xsl:number level="any" count="texttable[(@title!='' or @anchor!='') and not(@suppress-title='true')]" />
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="@format='counter'">
            <xsl:value-of select="$tabcnt" />
          </xsl:when>
          <xsl:when test="@format='title'">
            <xsl:value-of select="$node/@title" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(concat('Table&#160;',$tabcnt))"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:basic-link>
    </xsl:when>

    <!-- Paragraph links -->
    <xsl:when test="$node/self::t">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:variable name="tcnt">
          <xsl:for-each select="$node">
            <xsl:call-template name="get-paragraph-number" />
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="@format='counter'">
            <xsl:value-of select="$tcnt" />
          </xsl:when>
          <xsl:when test="@format='title'">
            <xsl:value-of select="$node/@title" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(concat('Paragraph&#160;',substring-after($tcnt,'p.')))"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:basic-link>
    </xsl:when>

    <!-- Comment links -->
    <xsl:when test="$node/self::cref">
      <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
        <xsl:variable name="name">
          <xsl:for-each select="$node">
            <xsl:call-template name="get-comment-name" />
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="@format='counter'">
            <xsl:value-of select="$name" />
          </xsl:when>
          <xsl:when test="@format='title'">
            <xsl:value-of select="$node/@title" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(concat('Comment&#160;',$name))"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:basic-link>
    </xsl:when>

    <!-- Reference links -->
    <xsl:when test="$node/self::reference">
      <!--
      Formats:
      
        ()      [XXXX] (Section SS)
        ,       [XXXX], Section SS
        of      Section SS of [XXXX]
        sec     Section SS
        number  SS
      -->

      <xsl:variable name="sec">
        <xsl:choose>
          <xsl:when test="starts-with(@x:rel,'#') and not(@x:sec) and $node/x:source/@href">
            <xsl:variable name="extdoc" select="document($node/x:source/@href)"/>
            <xsl:for-each select="$extdoc//*[@anchor=substring-after(current()/@x:rel,'#')]">
              <xsl:call-template name="get-section-number"/>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@x:sec"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="fmt">
        <xsl:choose>
          <xsl:when test="@x:fmt!=''"><xsl:value-of select="@x:fmt"/></xsl:when>
          <xsl:when test="ancestor::artwork">,</xsl:when>
          <xsl:otherwise>of</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:if test="$sec!=''">
        <xsl:choose>
          <xsl:when test="$fmt='of' or $fmt='sec'">
            <xsl:text>Section </xsl:text>
            <xsl:value-of select="$sec"/>
            <xsl:if test="$fmt='of'">
              <xsl:text> of </xsl:text>
            </xsl:if>
          </xsl:when>
          <xsl:when test="$fmt='number'">
            <xsl:value-of select="$sec"/>
          </xsl:when>
          <xsl:when test="$fmt=','"/>
          <xsl:when test="$fmt='()'"/>
          <xsl:otherwise>
            <xsl:message>UNKNOWN xref x:fmt: <xsl:value-of select="$fmt"/></xsl:message>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
      
      <!-- anchor for index -->
      <xsl:if test="$xml2rfc-ext-include-references-in-index='yes' and $sec!='' and ($fmt='sec' or $fmt='number')">
        <fo:wrapper>
          <xsl:attribute name="id">
            <xsl:value-of select="$anchor"/>
          </xsl:attribute>
          <xsl:attribute name="index-key">
            <xsl:value-of select="concat('xrefitem=',@target)"/>
          </xsl:attribute>
          <xsl:if test="$sec!=''">
            <fo:wrapper>
              <xsl:attribute name="index-key">
                <xsl:value-of select="concat('xrefitem=',@target,'#',$sec)"/>
              </xsl:attribute>
            </fo:wrapper>
          </xsl:if>
        </fo:wrapper>
      </xsl:if>

      <xsl:if test="$sec='' or ($fmt!='sec' and $fmt!='number')">
        <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link">
          <xsl:if test="$xml2rfc-ext-include-references-in-index='yes'">
            <xsl:attribute name="id">
              <xsl:value-of select="$anchor"/>
            </xsl:attribute>
            <xsl:attribute name="index-key">
              <xsl:value-of select="concat('xrefitem=',@target)"/>
            </xsl:attribute>
            <xsl:if test="$sec!=''">
              <fo:wrapper>
                <xsl:attribute name="index-key">
                  <xsl:value-of select="concat('xrefitem=',@target,'#',$sec)"/>
                </xsl:attribute>
              </fo:wrapper>
            </xsl:if>
          </xsl:if>
          <xsl:variable name="val">
            <xsl:call-template name="referencename">
              <xsl:with-param name="node" select="$node" />
            </xsl:call-template>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$fmt='anchor'">
              <!-- remove brackets -->
              <xsl:value-of select="substring($val,2,string-length($val)-2)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$val"/>
            </xsl:otherwise>
          </xsl:choose>
        </fo:basic-link>
      </xsl:if>

      <xsl:if test="$sec!=''">
        <xsl:choose>
          <xsl:when test="$fmt='()'">
            <xsl:text> (Section </xsl:text>
            <xsl:value-of select="$sec"/>
            <xsl:text>)</xsl:text>
          </xsl:when>
          <xsl:when test="$fmt=','">
            <xsl:text>, Section </xsl:text>
            <xsl:value-of select="$sec"/>
          </xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:if>

    </xsl:when>
    
    <xsl:otherwise>
      <xsl:call-template name="error">
        <xsl:with-param name="msg" select="concat('xref to unknown element: ',name($node))"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="/">
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="*">
  <xsl:message terminate="yes">ERROR: unknown or unexpected element: {<xsl:value-of select="namespace-uri()" />}<xsl:value-of select="local-name()" /><xsl:call-template name="lineno"/>: '<xsl:value-of select="."/>'</xsl:message>
</xsl:template>

<xsl:template name="emitheader">
  <xsl:param name="lc" />
  <xsl:param name="rc" />

  <xsl:for-each select="$lc/myns:item | $rc/myns:item">
    <xsl:variable name="pos" select="position()" />
    <xsl:if test="$pos &lt; count($lc/myns:item) + 1 or $pos &lt; count($rc/myns:item) + 1"> 
      <fo:table-row>
        <fo:table-cell>
          <fo:block>
            <xsl:apply-templates select="$lc/myns:item[$pos]/node()" mode="simple-html" /> 
          </fo:block>
        </fo:table-cell>
        <fo:table-cell>
          <fo:block text-align="right">
            <xsl:apply-templates select="$rc/myns:item[$pos]/node()" mode="simple-html" /> 
          </fo:block>
        </fo:table-cell>
      </fo:table-row>
    </xsl:if>
  </xsl:for-each>
</xsl:template>


<xsl:template match="text()" mode="simple-html">
  <xsl:apply-templates select="." />
</xsl:template>

<xsl:template match="a" mode="simple-html">
  <fo:basic-link external-destination="url('{@href}')" xsl:use-attribute-sets="external-link">
    <xsl:apply-templates />
  </fo:basic-link>
</xsl:template>


<!-- produce back section with author information -->
<xsl:template name="insertAuthors">

  <xsl:variable name="sectionNumber">
    <xsl:call-template name="get-authors-section-number"/>
  </xsl:variable>

  <xsl:if test="$sectionNumber!='suppress'">
    <fo:block id="{$anchor-prefix}.authors" xsl:use-attribute-sets="h1 newpage">
      <xsl:if test="$sectionNumber != ''">
        <xsl:call-template name="emit-section-number">
          <xsl:with-param name="no" select="$sectionNumber"/>
        </xsl:call-template>
        <xsl:text>&#0160;&#0160;</xsl:text>
      </xsl:if>
      <xsl:call-template name="get-authors-section-title"/>
    </fo:block>
    
    <xsl:apply-templates select="/rfc/front/author" />
  </xsl:if>
</xsl:template>


<!-- generate the index section -->

<xsl:template name="insertIndex">

  <fo:block xsl:use-attribute-sets="h1 newpage" id="{$anchor-prefix}.index">
    <xsl:text>Index</xsl:text>
  </fo:block>

  <xsl:variable name="irefs" select="//iref[generate-id(.) = generate-id(key('index-first-letter',translate(substring(@item,1,1),$lcase,$ucase)))]"/>
  <xsl:variable name="xrefs" select="//reference[generate-id(.) = generate-id(key('index-first-letter',translate(substring(@anchor,1,1),$lcase,$ucase)))]"/>

  <xsl:for-each select="$irefs | $xrefs">
    <xsl:sort select="translate(concat(@item,@anchor),$lcase,$ucase)" />
    <xsl:variable name="letter" select="translate(substring(concat(@item,@anchor),1,1),$lcase,$ucase)"/>
            
    <xsl:variable name="showit">
      <xsl:choose>
        <xsl:when test="$xml2rfc-ext-include-references-in-index!='yes'">
          <xsl:if test="$irefs[starts-with(translate(@item,$lcase,$ucase),$letter)]">
            <xsl:text>yes</xsl:text>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>yes</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:if test="$showit='yes'">
      <fo:block space-before="1em" font-weight="bold">
        <xsl:value-of select="$letter" />
      </fo:block>
            
      <xsl:for-each select="key('index-first-letter',translate(substring(concat(@item,@anchor),1,1),$lcase,$ucase))">
  
      <xsl:sort select="translate(concat(@item,@anchor),$lcase,$ucase)" />
      
        <xsl:choose>
          <xsl:when test="self::reference">
            <xsl:if test="$xml2rfc-ext-include-references-in-index='yes'">
            
              <xsl:variable name="entries" select="//xref[@target=current()/@anchor and not(ancestor::ed:del)]" />
              
              <xsl:if test="$entries">
                <fo:block start-indent="1em" hyphenate="true">
                  <fo:wrapper font-style="italic"><xsl:value-of select="concat(@anchor,' ')" /></fo:wrapper>
  
                  <fo:index-page-citation-list merge-sequential-page-numbers="merge">
                    <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('xrefitem=',@anchor,',primary')}" font-weight="bold"/>
                    <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('xrefitem=',@anchor)}"/>
                  </fo:index-page-citation-list>

                  <xsl:variable name="rs2" select="$entries[@x:sec]"/>

                  <xsl:if test="$rs2">
                    <xsl:for-each select="$rs2">
                      <xsl:sort select="substring-before(concat(@x:sec,'.'),'.')" data-type="number"/>
                      <xsl:sort select="substring(@x:sec,2+string-length(substring-before(@x:sec,'.')))" data-type="number"/>
                      <xsl:if test="generate-id(.) = generate-id(key('index-xref-by-sec',concat(@target,'..',@x:sec)))">
                        <fo:block start-indent="2em" hyphenate="true">
                          <fo:wrapper font-style="italic">
                            <xsl:choose>
                              <xsl:when test="translate(substring(@x:sec,1,1),$ucase,'')=''">
                                <xsl:text>Appendix </xsl:text>
                              </xsl:when>
                              <xsl:otherwise>
                                <xsl:text>Section </xsl:text>
                              </xsl:otherwise>
                            </xsl:choose>
                            <xsl:value-of select="@x:sec"/>
                            <xsl:text> </xsl:text>
                          </fo:wrapper>
                          <fo:index-page-citation-list merge-sequential-page-numbers="merge">
                            <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('xrefitem=',@target,'#',@x:sec)}"/>
                          </fo:index-page-citation-list>
                        </fo:block>
                      </xsl:if>
                    </xsl:for-each>
                  </xsl:if>

                  <xsl:if test="current()/x:source/@href">
                    <xsl:variable name="rs3" select="$entries[not(@x:sec) and @x:rel]"/>
                    <xsl:if test="$rs3">
                      <xsl:variable name="doc" select="document(current()/x:source/@href)"/>
                      <xsl:for-each select="$rs3">
                        <xsl:sort select="count($doc//*[@anchor and following::*/@anchor=substring-after(current()/@x:rel,'#')])" order="ascending" data-type="number"/>
                        <xsl:if test="generate-id(.) = generate-id(key('index-xref-by-anchor',concat(@target,'..',@x:rel)))">
                          <fo:block start-indent="2em" hyphenate="true">
                            <xsl:variable name="sec">
                              <xsl:for-each select="$doc//*[@anchor=substring-after(current()/@x:rel,'#')]">
                                <xsl:call-template name="get-section-number"/>
                              </xsl:for-each>
                            </xsl:variable>
                            <fo:wrapper font-style="italic">
                              <xsl:choose>
                                <xsl:when test="translate(substring($sec,1,1),$ucase,'')=''">
                                  <xsl:text>Appendix </xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                  <xsl:text>Section </xsl:text>
                                </xsl:otherwise>
                              </xsl:choose>
                              <xsl:value-of select="$sec"/>
                              <xsl:text> </xsl:text>
                            </fo:wrapper>
                            <fo:index-page-citation-list merge-sequential-page-numbers="merge">
                              <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('xrefitem=',@target,'#',$sec)}"/>
                            </fo:index-page-citation-list>
                          </fo:block>
                        </xsl:if>
                      </xsl:for-each>
                    </xsl:if>
                  </xsl:if>

                </fo:block>
              </xsl:if>

            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:if test="generate-id(.) = generate-id(key('index-item',@item))">
            
              <xsl:variable name="item" select="@item"/>
              <xsl:variable name="in-artwork" select="count(//iref[@item=$item and @primary='true' and ancestor::artwork])!=0"/>
        
              <fo:block start-indent="1em" hyphenate="true">
                <xsl:choose>
                  <xsl:when test="$in-artwork">
                    <fo:wrapper font-family="monospace"><xsl:value-of select="concat(@item,' ')" /></fo:wrapper>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="concat(@item,' ')" />
                  </xsl:otherwise>
                </xsl:choose>
                
                <xsl:variable name="entries" select="key('index-item',@item)[not(@subitem) or @subitem='']"/>
                                        
                <xsl:if test="$entries">
                  <fo:index-page-citation-list merge-sequential-page-numbers="merge">
                    <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('item=',@item,',subitem=',@subitem,',primary')}" font-weight="bold"/>
                    <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('item=',@item,',subitem=',@subitem)}"/>
                  </fo:index-page-citation-list>
                </xsl:if>
      
              </fo:block>
                    
              <xsl:for-each select="key('index-item',@item)[@subitem and @subitem!='']">
              <xsl:sort select="translate(@subitem,$lcase,$ucase)" />
            
                <xsl:if test="generate-id(.) = generate-id(key('index-item-subitem',concat(@item,'..',@subitem)))">
                
                  <xsl:variable name="itemsubitem" select="concat(@item,'..',@subitem)"/>
                  <xsl:variable name="in-artwork2" select="count(//iref[concat(@item,'..',@subitem)=$itemsubitem and @primary='true' and ancestor::artwork])!=0"/>
                              
                  <fo:block start-indent="2em" hyphenate="true">
                  
                    <xsl:choose>
                      <xsl:when test="$in-artwork2">
                        <fo:wrapper font-family="monospace"><xsl:value-of select="concat(@subitem,' ')" /></fo:wrapper>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="concat(@subitem,' ')" />
                      </xsl:otherwise>
                    </xsl:choose>
      
                    <xsl:variable name="entries2" select="key('index-item-subitem',concat(@item,'..',@subitem))" />
                    
                    <xsl:if test="$entries2">
                      <fo:index-page-citation-list merge-sequential-page-numbers="merge">
                        <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('item=',@item,',subitem=',@subitem,',primary')}" font-weight="bold"/>
                        <fo:index-key-reference page-number-treatment="link" ref-index-key="{concat('item=',@item,',subitem=',@subitem)}" />
                      </fo:index-page-citation-list>
                    </xsl:if>
      
                  </fo:block>
                </xsl:if>
              </xsl:for-each>
                      
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
    
                  
      </xsl:for-each>            
    </xsl:if>
  </xsl:for-each>
</xsl:template>



<xsl:template match="/" mode="toc">
  <fo:block xsl:use-attribute-sets="h1 newpage" id="{concat($anchor-prefix,'.toc')}">
    <xsl:text>Table of Contents</xsl:text>
  </fo:block>

  <xsl:apply-templates mode="toc" />
</xsl:template>

<xsl:template name="back-toc">

  <xsl:apply-templates select="references" mode="toc" />

  <xsl:if test="$xml2rfc-ext-authors-section!='end'">
    <xsl:apply-templates select="/rfc/front" mode="toc" />
  </xsl:if>

  <xsl:apply-templates select="back/*[not(self::references)]" mode="toc" />

  <!-- insert the index if index entries exist -->
  <xsl:if test="$has-index">
    <xsl:call-template name="insert-toc-line">
      <xsl:with-param name="target" select="concat($anchor-prefix,'.index')"/>
      <xsl:with-param name="title" select="'Index'"/>
    </xsl:call-template>
  </xsl:if>

  <xsl:if test="$xml2rfc-ext-authors-section='end'">
    <xsl:apply-templates select="/rfc/front" mode="toc" />
  </xsl:if>

  <!-- copyright statements -->
  <xsl:if test="$xml2rfc-private='' and not($no-copylong)">
    <xsl:call-template name="insert-toc-line">
      <xsl:with-param name="target" select="concat($anchor-prefix,'.ipr')"/>
      <xsl:with-param name="title" select="'Intellectual Property and Copyright Statements'"/>
    </xsl:call-template>
  </xsl:if>
  
</xsl:template>

<xsl:template match="front" mode="toc">
  
  <xsl:variable name="authors-title">
    <xsl:call-template name="get-authors-section-title"/>
  </xsl:variable>
  <xsl:variable name="authors-number">
    <xsl:call-template name="get-authors-section-number"/>
  </xsl:variable>
  <xsl:if test="$authors-number!='suppress'">
    <xsl:call-template name="insert-toc-line">
      <xsl:with-param name="target" select="concat($anchor-prefix,'.authors')"/>
      <xsl:with-param name="title" select="$authors-title"/>
      <xsl:with-param name="number" select="$authors-number"/>
    </xsl:call-template>
  </xsl:if>

</xsl:template>

<xsl:template name="references-toc">

  <!-- distinguish two cases: (a) single references element (process
  as toplevel section; (b) multiple references sections (add one toplevel
  container with subsection) -->

  <xsl:choose>
    <xsl:when test="count(/*/back/references) = 0">
      <!-- nop -->
    </xsl:when>
    <xsl:when test="count(/*/back/references) = 1">
      <xsl:for-each select="/*/back/references">
        <xsl:variable name="title">
          <xsl:choose>
            <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
            <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
      
        <xsl:call-template name="insert-toc-line">
          <xsl:with-param name="number">
            <xsl:call-template name="get-references-section-number"/>
          </xsl:with-param>
          <xsl:with-param name="target" select="concat($anchor-prefix,'.references')"/>
          <xsl:with-param name="title" select="$title"/>
        </xsl:call-template>
      </xsl:for-each>
    </xsl:when>
    <xsl:otherwise>
      <!-- insert pseudo container -->    
      <xsl:call-template name="insert-toc-line">
        <xsl:with-param name="number">
          <xsl:call-template name="get-references-section-number"/>
        </xsl:with-param>
        <xsl:with-param name="target" select="concat($anchor-prefix,'.references')"/>
        <xsl:with-param name="title" select="$xml2rfc-refparent"/>
      </xsl:call-template>
  
      <!-- ...with subsections... -->    
      <xsl:for-each select="/*/back/references">
        <xsl:variable name="title">
          <xsl:choose>
            <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
            <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
      
        <xsl:variable name="sectionNumber">
          <xsl:call-template name="get-section-number" />
        </xsl:variable>

        <xsl:variable name="num">
          <xsl:number/>
        </xsl:variable>

        <xsl:call-template name="insert-toc-line">
          <xsl:with-param name="number" select="$sectionNumber"/>
          <xsl:with-param name="target" select="concat($anchor-prefix,'.references','.',$num)"/>
          <xsl:with-param name="title" select="$title"/>
        </xsl:call-template>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="section" mode="toc">
  <xsl:variable name="sectionNumber">
    <xsl:call-template name="get-section-number" />
  </xsl:variable>

  <xsl:variable name="target">
    <xsl:choose>
      <xsl:when test="@anchor"><xsl:value-of select="@anchor" /></xsl:when>
       <xsl:otherwise><xsl:value-of select="$anchor-prefix"/>.section.<xsl:value-of select="$sectionNumber" /></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:call-template name="insert-toc-line">
    <xsl:with-param name="number" select="$sectionNumber"/>
    <xsl:with-param name="target" select="$target"/>
    <xsl:with-param name="title" select="@title"/>
    <xsl:with-param name="tocparam" select="@toc"/>
  </xsl:call-template>
  
  <xsl:if test=".//section">
    <xsl:apply-templates mode="toc" />
  </xsl:if>
</xsl:template>

<xsl:template name="insert-toc-line">
  <xsl:param name="number" />
  <xsl:param name="target" />
  <xsl:param name="title" />
  <xsl:param name="tocparam" />
  
  <xsl:variable name="depth" select="string-length(translate($number,'.ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890&#167;','.'))" />
  
  <!-- handle tocdepth parameter -->
  <xsl:choose>
    <xsl:when test="($tocparam='' or $tocparam='default') and string-length(translate($number,'.ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890&#167;','.')) &gt;= $parsedTocDepth">
      <!-- dropped entry because of depth-->
    </xsl:when>
    <xsl:when test="$tocparam='exclude'">
      <!-- dropped entry because excluded -->
    </xsl:when>
    <xsl:when test="$depth = 0">
      <fo:block space-before="1em" font-weight="bold" text-align-last="justify">
        <xsl:if test="$number!='' and not(contains($number,'unnumbered-'))">
          <xsl:value-of select="$number" />
          <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
          <xsl:text>&#0160;&#0160;</xsl:text>
        </xsl:if>
        <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link"><xsl:value-of select="$title"/></fo:basic-link>
        <fo:leader leader-pattern="dots"/>
        <fo:page-number-citation ref-id="{$target}"/>
      </fo:block>
    </xsl:when>
    <xsl:when test="$depth = 1">
      <fo:block space-before="0.5em" text-align-last="justify">
        <xsl:if test="$number!='' and not(contains($number,'unnumbered-'))">
          <xsl:value-of select="$number" />
          <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
          <xsl:text>&#0160;&#0160;&#0160;&#0160;</xsl:text>
        </xsl:if>
        <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link"><xsl:value-of select="$title"/></fo:basic-link>
        <fo:leader leader-pattern="dots"/>
        <fo:page-number-citation ref-id="{$target}"/>
      </fo:block>
    </xsl:when>
    <xsl:otherwise>
      <fo:block text-align-last="justify">
        <xsl:text>&#0160;&#0160;</xsl:text>
        <xsl:if test="$number!='' and not(contains($number,'unnumbered-'))">
          <xsl:value-of select="$number" />
          <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
          <xsl:text>&#0160;&#0160;&#0160;&#0160;</xsl:text>
        </xsl:if>
        <fo:basic-link internal-destination="{$target}" xsl:use-attribute-sets="internal-link"><xsl:value-of select="$title"/></fo:basic-link>
        <fo:leader leader-pattern="dots"/>
        <fo:page-number-citation ref-id="{$target}"/>
      </fo:block>
    </xsl:otherwise>
  </xsl:choose>

</xsl:template>


<!--
<xsl:template name="rfclist">
  <xsl:param name="list" />
  <xsl:choose>
      <xsl:when test="contains($list,',')">
          <xsl:variable name="rfcNo" select="substring-before($list,',')" />
          <a href="{concat($rfcUrlPrefix,$rfcNo,'.txt')}"><xsl:value-of select="$rfcNo" /></a>,
          <xsl:call-template name="rfclist">
              <xsl:with-param name="list" select="normalize-space(substring-after($list,','))" />
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="rfcNo" select="$list" />
          <a href="{concat($rfcUrlPrefix,$rfcNo,'.txt')}"><xsl:value-of select="$rfcNo" /></a>
         </xsl:otherwise>
    </xsl:choose>
</xsl:template>
-->

<xsl:template name="insertHeader">
  <xsl:variable name="left">
    <xsl:call-template name="get-header-left" />
  </xsl:variable>
  <xsl:variable name="center">
    <xsl:call-template name="get-header-center" />
  </xsl:variable>
  <xsl:variable name="right">
    <xsl:call-template name="get-header-right" />
  </xsl:variable>

  <fo:static-content flow-name="header-right">
    <fo:block space-after=".5cm" />
    <fo:table width="100%" text-align="center" table-layout="fixed">
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-column column-width="proportional-column-width({string-length($center)})" />
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell>
            <fo:block text-align="start">
              <xsl:value-of select="$left" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell text-align="center">
            <fo:block>
              <xsl:value-of select="$center" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell text-align="end">
            <fo:block>
              <xsl:value-of select="$right" />
             </fo:block>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </fo:static-content>

  <fo:static-content flow-name="header-left">
    <fo:block space-after=".5cm" />
    <fo:table width="100%" text-align="center" table-layout="fixed">
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-column column-width="proportional-column-width({string-length($center)})" />
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell text-align="start">
            <fo:block>
              <xsl:value-of select="$right" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell text-align="center">
            <fo:block>
              <xsl:value-of select="$center" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block text-align="end">
              <xsl:value-of select="$left" />
             </fo:block>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </fo:static-content>

</xsl:template>

<xsl:template name="insertFooter">
  <xsl:variable name="left">
    <xsl:call-template name="get-author-summary" />
  </xsl:variable>
  <xsl:variable name="center">
    <xsl:call-template name="get-bottom-center" />
  </xsl:variable>
  <xsl:variable name="right">[Page 999]</xsl:variable>

  <fo:static-content flow-name="footer-right">
    <fo:table text-align="center" width="100%" table-layout="fixed">
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-column column-width="proportional-column-width({string-length($center)})" />
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell>
            <fo:block text-align="start">
              <xsl:value-of select="$left" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block text-align="center">
              <xsl:value-of select="$center" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block text-align="end">[Page <fo:page-number />]</fo:block>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </fo:static-content>

  <fo:static-content flow-name="footer-left">
    <fo:table text-align="center" width="100%" table-layout="fixed">
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-column column-width="proportional-column-width({string-length($center)})" />
      <fo:table-column column-width="proportional-column-width({(string-length($left)+string-length($right)) div 2})" />
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell>
            <fo:block text-align="start">[Page <fo:page-number />]</fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block text-align="center">
              <xsl:value-of select="$center" />
             </fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block text-align="end">
              <xsl:value-of select="$left" />
             </fo:block>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </fo:static-content>

</xsl:template>

<!-- change tracking -->

<xsl:template match="ed:annotation" />
<xsl:template match="ed:del" />
<xsl:template match="ed:issue" />
<xsl:template match="ed:ins">
  <xsl:apply-templates />
</xsl:template>
<xsl:template match="ed:issueref">
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="ed:replace">
  <!--<xsl:variable name="no">change<xsl:number level="any"/></xsl:variable>
  <fo:change-bar-begin change-bar-class="{$no}" change-bar-style="solid" change-bar-color="red" change-bar-offset="2mm"/>-->
  <xsl:apply-templates />
  <!--<fo:change-bar-end change-bar-class="{$no}"/>-->
</xsl:template>

<!-- extensions -->

<xsl:template match="ed:link" />


<xsl:template match="node()" mode="bookmarks">
  <xsl:apply-templates mode="bookmarks"/>
</xsl:template>

<xsl:template match="abstract" mode="bookmarks">
  <fo:bookmark internal-destination="{concat($anchor-prefix,'.abstract')}">
    <fo:bookmark-title>Abstract</fo:bookmark-title>
    <xsl:apply-templates mode="bookmarks"/>
  </fo:bookmark>
</xsl:template>

<xsl:template match="note" mode="bookmarks">
  <xsl:variable name="num">
    <xsl:number count="note" />
  </xsl:variable>
  <fo:bookmark internal-destination="{concat($anchor-prefix,'.note.',$num)}">
    <fo:bookmark-title><xsl:value-of select="@title"/></fo:bookmark-title>
    <xsl:apply-templates mode="bookmarks"/>
  </fo:bookmark>
</xsl:template>

<xsl:template match="section[not(@myns:unnumbered)]" mode="bookmarks">
  <xsl:variable name="sectionNumber"><xsl:call-template name="get-section-number" /></xsl:variable>
  <fo:bookmark internal-destination="{$anchor-prefix}.section.{$sectionNumber}">
    <fo:bookmark-title>
      <xsl:if test="$sectionNumber!='' and not(contains($sectionNumber,'unnumbered-'))">
        <xsl:value-of select="$sectionNumber"/>
        <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:value-of select="@title"/>
    </fo:bookmark-title>
    <xsl:apply-templates mode="bookmarks"/>
  </fo:bookmark>
</xsl:template>

<xsl:template match="section[@myns:unnumbered]" mode="bookmarks">
  <fo:bookmark internal-destination="{@anchor}">
    <fo:bookmark-title><xsl:value-of select="@title"/></fo:bookmark-title>
    <xsl:apply-templates mode="bookmarks"/>
  </fo:bookmark>
</xsl:template>

<xsl:template match="back" mode="bookmarks">

  <xsl:call-template name="references-bookmarks" />

  <xsl:if test="$xml2rfc-ext-authors-section!='end'">
    <xsl:apply-templates select="/rfc/front" mode="bookmarks" />
  </xsl:if>
  
  <xsl:apply-templates select="*[not(self::references)]" mode="bookmarks" />

  <!-- insert the index if index entries exist -->
  <xsl:if test="$has-index">
    <fo:bookmark internal-destination="{concat($anchor-prefix,'.index')}">
      <fo:bookmark-title>Index</fo:bookmark-title>
    </fo:bookmark>
  </xsl:if>

  <xsl:if test="$xml2rfc-ext-authors-section='end'">
    <xsl:apply-templates select="/rfc/front" mode="bookmarks" />
  </xsl:if>

  <xsl:if test="$xml2rfc-private='' and not($no-copylong)">
    <!-- copyright statements -->
    <fo:bookmark internal-destination="{concat($anchor-prefix,'.ipr')}">
      <fo:bookmark-title>Intellectual Property and Copyright Statements</fo:bookmark-title>
    </fo:bookmark>
  </xsl:if>
  
</xsl:template>

<xsl:template match="front" mode="bookmarks">

  <xsl:variable name="authors-number">
    <xsl:call-template name="get-authors-section-number"/>
  </xsl:variable>

  <xsl:variable name="title">
    <xsl:if test="$authors-number!=''">
      <xsl:value-of select="$authors-number"/>
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:call-template name="get-authors-section-title"/>
  </xsl:variable>

  <xsl:if test="$authors-number!='suppress'">
    <fo:bookmark internal-destination="{concat($anchor-prefix,'.authors')}">
      <fo:bookmark-title><xsl:value-of select="$title"/></fo:bookmark-title>
    </fo:bookmark>
  </xsl:if>
</xsl:template>

<xsl:template match="middle" mode="bookmarks">
  <xsl:apply-templates mode="bookmarks" />
</xsl:template>

<xsl:template name="references-bookmarks">

  <!-- distinguish two cases: (a) single references element (process
  as toplevel section; (b) multiple references sections (add one toplevel
  container with subsection) -->

  <xsl:choose>
    <xsl:when test="count(/*/back/references) = 0">
      <!-- nothing to do -->
    </xsl:when>
    <xsl:when test="count(/*/back/references) = 1">
      <xsl:for-each select="/*/back/references">
        <xsl:variable name="title">
          <xsl:choose>
            <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
            <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
      
        <fo:bookmark internal-destination="{$anchor-prefix}.references">
          <fo:bookmark-title>
            <xsl:call-template name="get-references-section-number"/>
            <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
            <xsl:text> </xsl:text>
            <xsl:value-of select="$title"/>
          </fo:bookmark-title>
        </fo:bookmark>
      </xsl:for-each>
    </xsl:when>
    <xsl:otherwise>
      <!-- insert pseudo container -->    
      <fo:bookmark internal-destination="{$anchor-prefix}.references">
        <fo:bookmark-title>
          <xsl:call-template name="get-references-section-number"/>
          <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$xml2rfc-refparent"/>
        </fo:bookmark-title>

        <!-- ...with subsections... -->    
        <xsl:for-each select="/*/back/references">
          <xsl:variable name="title">
            <xsl:choose>
              <xsl:when test="@title!=''"><xsl:value-of select="@title" /></xsl:when>
              <xsl:otherwise><xsl:value-of select="$xml2rfc-refparent"/></xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
        
          <xsl:variable name="sectionNumber">
            <xsl:call-template name="get-section-number" />
            <xsl:if test="$xml2rfc-ext-sec-no-trailing-dots='yes'">.</xsl:if>
          </xsl:variable>
  
          <xsl:variable name="num">
            <xsl:number/>
          </xsl:variable>
  
          <fo:bookmark internal-destination="{$anchor-prefix}.references.{$num}">
            <fo:bookmark-title><xsl:value-of select="concat($sectionNumber,' ',$title)"/></fo:bookmark-title>
          </fo:bookmark>
        </xsl:for-each>
      </fo:bookmark>

    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="rfc" mode="bookmarks">
  <xsl:if test="$xml2rfc-private='' and not($abstract-first)">
    <xsl:call-template name="emit-ietf-preamble-bookmarks"/>    
  </xsl:if>
  
  <xsl:apply-templates select="front/abstract" mode="bookmarks"/>
  <xsl:apply-templates select="front/note[@title!='IESG Note' or $xml2rfc-private!='']" mode="bookmarks"/>

  <xsl:if test="$xml2rfc-private='' and $abstract-first">
    <xsl:call-template name="emit-ietf-preamble-bookmarks"/>    
  </xsl:if>

  <xsl:if test="$xml2rfc-toc='yes'">
    <fo:bookmark internal-destination="{concat($anchor-prefix,'.toc')}">
      <fo:bookmark-title>Table of Contents</fo:bookmark-title>
    </fo:bookmark>
  </xsl:if>
  
  <xsl:apply-templates select="middle|back" mode="bookmarks"/>
</xsl:template>

<xsl:template name="emit-ietf-preamble-bookmarks">
  <!-- Get status info formatted as per RFC2629-->
  <xsl:variable name="preamble"><xsl:call-template name="insertPreamble" /></xsl:variable>
  
  <!-- emit it -->
  <xsl:choose>
    <xsl:when test="function-available('exslt:node-set')">
      <xsl:apply-templates select="exslt:node-set($preamble)/node()" mode="bookmarks"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="temp" select="$preamble"/>
      <xsl:apply-templates select="$temp/node()" mode="bookmarks"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- experimental table formatting -->

<xsl:template name="sum-widths">
  <xsl:param name="list"/>
  <xsl:choose>
    <xsl:when test="count($list)=0">
      <xsl:value-of select="0"/>
    </xsl:when>
    <xsl:when test="count($list)=1">
      <xsl:value-of select="number(substring-before($list[1],'%'))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="remainder">
        <xsl:call-template name="sum-widths">
          <xsl:with-param name="list" select="$list[position()>1]" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:value-of select="$remainder + number(substring-before($list[1],'%'))" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
<xsl:attribute-set name="all-borders-solid">
  <xsl:attribute name="border-left-style">solid</xsl:attribute>
  <xsl:attribute name="border-right-style">solid</xsl:attribute>
  <xsl:attribute name="border-top-style">solid</xsl:attribute>
  <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
  <xsl:attribute name="border-left-width">thin</xsl:attribute>
  <xsl:attribute name="border-right-width">thin</xsl:attribute>
  <xsl:attribute name="border-top-width">thin</xsl:attribute>
  <xsl:attribute name="border-bottom-width">thin</xsl:attribute>
  <xsl:attribute name="padding-left">0.5em</xsl:attribute>
  <xsl:attribute name="padding-right">0.5em</xsl:attribute>
</xsl:attribute-set>

-->

<xsl:template match="texttable">

  <xsl:variable name="style">
    <xsl:choose>
      <xsl:when test="@style!=''">
        <xsl:value-of select="@style"/>
      </xsl:when>
      <xsl:otherwise>full</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="anch">
    <xsl:call-template name="get-table-anchor"/>
  </xsl:variable>

  <fo:block space-before=".5em" space-after=".5em" start-indent="2em" id="{$anch}">
    <xsl:call-template name="add-anchor"/>
    <xsl:apply-templates select="preamble" />
    <fo:table>
      <xsl:variable name="total-specified">
        <xsl:call-template name="sum-widths">
          <xsl:with-param name="list" select="ttcol/@width" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="ttcol">
        <fo:table-column>
          <xsl:choose>
            <xsl:when test="@width">
              <xsl:attribute name="column-width">proportional-column-width(<xsl:value-of select="substring-before(@width,'%')" />)</xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="column-width">proportional-column-width(<xsl:value-of select="(100 - number($total-specified)) div count(../ttcol[not(@width)])" />)</xsl:attribute>
            </xsl:otherwise>
          </xsl:choose>
        </fo:table-column>
      </xsl:for-each>
      <xsl:if test="ttcol!=''">
        <!-- skip header when all column titles are empty -->
        <fo:table-header start-indent="0em" space-after=".5em">
          <fo:table-row>
            <xsl:apply-templates select="ttcol" />
          </fo:table-row>
        </fo:table-header>
      </xsl:if>
      <fo:table-body start-indent="0em">
        <xsl:if test="$style='full' or $style='headers'">
          <xsl:attribute name="border-left-style">solid</xsl:attribute>
          <xsl:attribute name="border-right-style">solid</xsl:attribute>
          <xsl:attribute name="border-top-style">solid</xsl:attribute>
          <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
          <xsl:attribute name="border-left-width">thin</xsl:attribute>
          <xsl:attribute name="border-right-width">thin</xsl:attribute>
          <xsl:attribute name="border-top-width">thin</xsl:attribute>
          <xsl:attribute name="border-bottom-width">thin</xsl:attribute>
        </xsl:if>
        <xsl:variable name="columns" select="count(ttcol)" />
        <xsl:for-each select="c[$columns=1 or (position() mod $columns) = 1]">
          <fo:table-row>
            <xsl:for-each select=". | following-sibling::c[position() &lt; $columns]">
              <fo:table-cell padding-left="0.5em" padding-right="0.5em">
                <xsl:if test="$style='full' or $style='headers'">
                  <xsl:attribute name="border-left-style">solid</xsl:attribute>
                  <xsl:attribute name="border-right-style">solid</xsl:attribute>
                  <xsl:attribute name="border-left-width">thin</xsl:attribute>
                  <xsl:attribute name="border-right-width">thin</xsl:attribute>
                </xsl:if>
                <xsl:if test="$style='full'">
                  <xsl:attribute name="border-top-style">solid</xsl:attribute>
                  <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
                  <xsl:attribute name="border-top-width">thin</xsl:attribute>
                  <xsl:attribute name="border-bottom-width">thin</xsl:attribute>
                </xsl:if>
                <fo:block>
                  <xsl:variable name="pos" select="position()" />
                  <xsl:variable name="col" select="../ttcol[position() = $pos]" />
                  <xsl:if test="$col/@align">
                    <xsl:attribute name="text-align"><xsl:value-of select="$col/@align" /></xsl:attribute>
                  </xsl:if>
                  <xsl:apply-templates select="node()" />
                </fo:block>
              </fo:table-cell>
            </xsl:for-each>
          </fo:table-row>
        </xsl:for-each>
      </fo:table-body>
    </fo:table>
    <xsl:apply-templates select="postamble" />
    <xsl:if test="(@title!='' or @anchor!='') and not(@suppress-title='true')">
      <xsl:variable name="n"><xsl:number level="any" count="texttable[(@title!='' or @anchor!='') and not(@suppress-title='true')]" /></xsl:variable>
      <fo:block text-align="center" space-before="1em" space-after="1em">Table <xsl:value-of select="$n"/><xsl:if test="@title!=''">: <xsl:value-of select="@title" /></xsl:if></fo:block>
    </xsl:if>
  </fo:block>
</xsl:template>

<xsl:template match="ttcol">
  <xsl:variable name="style">
    <xsl:choose>
      <xsl:when test="../@style!=''">
        <xsl:value-of select="../@style"/>
      </xsl:when>
      <xsl:otherwise>full</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <fo:table-cell padding-left="0.5em" padding-right="0.5em">
    <xsl:if test="$style='full' or $style='headers'">
      <xsl:attribute name="border-left-style">solid</xsl:attribute>
      <xsl:attribute name="border-right-style">solid</xsl:attribute>
      <xsl:attribute name="border-top-style">solid</xsl:attribute>
      <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
      <xsl:attribute name="border-left-width">thin</xsl:attribute>
      <xsl:attribute name="border-right-width">thin</xsl:attribute>
      <xsl:attribute name="border-top-width">thin</xsl:attribute>
      <xsl:attribute name="border-bottom-width">thin</xsl:attribute>
    </xsl:if>
<!--    <xsl:if test="@width">
      <xsl:attribute name="width"><xsl:value-of select="@width" /></xsl:attribute>
    </xsl:if> -->
    <xsl:choose>
      <xsl:when test="@align">
        <xsl:attribute name="text-align"><xsl:value-of select="@align" /></xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="text-align">left</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <fo:block font-weight="bold">
      <xsl:apply-templates />
    </fo:block>
  </fo:table-cell>
</xsl:template>

<xsl:template name="add-anchor">
  <xsl:if test="@anchor">
    <fo:block id="{@anchor}" />
  </xsl:if>
</xsl:template>

<!-- cref support -->

<xsl:template match="cref">
  <xsl:if test="$xml2rfc-comments!='no'">
    <xsl:variable name="cid">
      <xsl:call-template name="get-comment-name"/>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="$xml2rfc-inline!='yes'">
        <fo:footnote>
          <fo:inline>
            <fo:basic-link font-size="8pt" vertical-align="super" internal-destination="{$cid}">[<xsl:value-of select="$cid"/>]</fo:basic-link>
          </fo:inline>
          <fo:footnote-body>
            <fo:block font-size="10pt" start-indent="2em" text-align="left" id="{$cid}">
              <fo:inline font-size="8pt" vertical-align="super">[<xsl:value-of select="$cid"/>]</fo:inline>
              <xsl:text> </xsl:text>
              <xsl:apply-templates select="node()"/>
              <xsl:if test="@source"> --<xsl:value-of select="@source"/></xsl:if>
            </fo:block>
          </fo:footnote-body>
        </fo:footnote>
      </xsl:when>
      <xsl:otherwise>
        <fo:inline xsl:use-attribute-sets="comment">
          <xsl:text>[</xsl:text>
          <xsl:value-of select="$cid"/>
          <xsl:text>: </xsl:text>
          <xsl:apply-templates select="node()"/>
          <xsl:if test="@source"> --<xsl:value-of select="@source"/></xsl:if>
          <xsl:text>]</xsl:text>
        </fo:inline>
      </xsl:otherwise>
    </xsl:choose>    
  </xsl:if>
</xsl:template>



<xsl:template name="insert-justification">
  <xsl:if test="$xml2rfc-ext-justification='always' or $xml2rfc-ext-justification='print'">
    <xsl:attribute name="text-align">justify</xsl:attribute>
  </xsl:if>
</xsl:template>

<!-- Extensions -->

<!-- Nothing to do for PDF output -->
<xsl:template match="x:assign-section-number" />
<xsl:template match="x:link" />

<!-- Nothing to do here -->
<xsl:template match="x:anchor-alias" />

<!-- internal ref support -->
<xsl:template match="x:ref">
  <xsl:variable name="val" select="."/>
  <xsl:variable name="target" select="//*[(@anchor and x:anchor-alias/@value=$val) or (@anchor=$val)]"/>
  <xsl:choose>
    <xsl:when test="$target">
      <fo:basic-link internal-destination="{$target/@anchor}" xsl:use-attribute-sets="internal-link">
        <xsl:call-template name="copy-anchor"/>
        <xsl:apply-templates/>
      </fo:basic-link>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="warning">
        <xsl:with-param name="msg">internal link target for '<xsl:value-of select="."/>' does not exist.</xsl:with-param>
      </xsl:call-template>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- BCP14 keywords -->
<xsl:template match="x:bcp14">
  <!-- figure out something that prints well -->
  <xsl:apply-templates/>
</xsl:template>

<!-- Notes -->
<xsl:template match="x:note">
  <xsl:apply-templates/>
</xsl:template>

<!-- Quotes -->
<xsl:template match="x:blockquote">
  <fo:block font-style="italic" space-before=".5em" space-after=".5em" start-indent="3em"
      border-left-style="solid" border-left-color="gray" border-left-width=".25em" padding-left=".5em">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="x:q">
  <fo:wrapper font-style="italic">
    <xsl:text>&#8220;</xsl:text>
    <xsl:apply-templates/>
    <xsl:text>&#8221;</xsl:text>
  </fo:wrapper>
</xsl:template>

<!-- Definitions -->
<xsl:template match="x:dfn">
  <fo:wrapper font-style="italic">
    <xsl:if test="not(preceding-sibling::x:dfn) and count(following-sibling::list)=1">
      <xsl:attribute name="keep-with-next">always</xsl:attribute>
    </xsl:if>
    <xsl:apply-templates/>
  </fo:wrapper>
</xsl:template>

<!-- Headings -->
<xsl:template match="x:h">
  <fo:wrapper font-weight="bold">
    <xsl:apply-templates/>
  </fo:wrapper>
</xsl:template>

<!-- Highlightinghing -->
<xsl:template match="x:highlight">
  <fo:wrapper font-weight="bold">
    <xsl:apply-templates/>
  </fo:wrapper>
</xsl:template>

<!-- Superscripts -->
<xsl:template match="x:sup">
  <xsl:text>^</xsl:text> <!-- make this prettier -->
  <xsl:apply-templates/>
</xsl:template>

<!-- measuring lengths -->
<xsl:template match="x:length-of">
  <xsl:variable name="target" select="//*[@anchor=current()/@target]"/>
  <xsl:if test="count($target)!=1">
    <xsl:call-template name="error">
      <xsl:with-param name="msg" select="concat('@target ',@target,' defined ',count($target),' times.')"/>
    </xsl:call-template>
  </xsl:if>
  <xsl:variable name="content">
    <xsl:apply-templates select="$target"/>
  </xsl:variable>
  <xsl:variable name="lineends" select="string-length($content) - string-length(translate($content,'&#10;',''))"/>
  <xsl:variable name="indents">
    <xsl:choose>
      <xsl:when test="@indented">
        <xsl:value-of select="number(@indented) * $lineends"/>
      </xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:value-of select="string-length($content) + $lineends - $indents"/>
</xsl:template>

<!-- Nop -->
<xsl:template match="x:span">
  <xsl:apply-templates/>
</xsl:template>

<!-- XML checking -->
<xsl:template match="x:parse-xml">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="x:abnf-char-sequence">
  <xsl:choose>
    <xsl:when test="substring(.,1,1) != '&quot;' or substring(.,string-length(.),1) != '&quot;'">
      <xsl:call-template name="error">
        <xsl:with-param name="msg" select="'contents of x:abnf-char-sequence needs to be quoted.'" />
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>%x</xsl:text>
      <xsl:call-template name="to-abnf-char-sequence">
        <xsl:with-param name="chars" select="substring(.,2,string-length(.)-2)"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- inlined RDF support -->
<xsl:template match="rdf:Description">
  <!-- ignore -->
</xsl:template>

<!-- box drawing -->

<!-- nop for alignment -->
<xsl:template match="x:x"/>

<!-- box -->
<xsl:template match="x:bt|x:bc|x:bb">
  <xsl:apply-templates />
</xsl:template>

<!-- author handling extensions -->
<xsl:template match="x:include-author">
  <xsl:for-each select="/*/front/author[@anchor=current()/@target]">
    <xsl:apply-templates select="."/>
  </xsl:for-each>
</xsl:template>

<!-- boilerplate -->
<xsl:template match="x:boilerplate">
  <xsl:apply-templates/>
</xsl:template>

  <!-- experimental: format URI with zero-width spaces to ease line breaks -->
  
  <xsl:template name="format-uri">
    <xsl:param name="s"/>
    <xsl:param name="mode"/>
    
    <xsl:choose>
      <!-- optimization for not hypenating the scheme name -->
      <xsl:when test="$mode!='after-scheme' and string-length(substring-before($s,':')) > 2">
        <xsl:value-of select="concat(substring-before($s,':'),':&#x200b;')"/>
        <xsl:call-template name="format-uri">
          <xsl:with-param name="s" select="substring-after($s,':')"/>
          <xsl:with-param name="mode" select="'after-scheme'"/>
        </xsl:call-template>
      </xsl:when>
      <!-- do no insert break points after hyphens -->
      <xsl:when test="starts-with($s,'-')">
        <xsl:text>-</xsl:text>
        <xsl:call-template name="format-uri">
          <xsl:with-param name="s" select="substring($s,2)"/>
          <xsl:with-param name="mode" select="'after-scheme'"/>
        </xsl:call-template>
      </xsl:when>
      <!-- last char?-->
      <xsl:when test="string-length($s)=1">
        <xsl:value-of select="$s"/>
      </xsl:when>
      <!-- add one zwsp after each character -->
      <xsl:when test="$s!=''">
        <xsl:value-of select="concat(substring($s,1,1),'&#x200b;')"/>
        <xsl:call-template name="format-uri">
          <xsl:with-param name="s" select="substring($s,2)"/>
          <xsl:with-param name="mode" select="'after-scheme'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <!-- done -->
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>

</xsl:transform>