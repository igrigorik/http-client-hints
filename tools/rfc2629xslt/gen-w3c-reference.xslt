<!--
    Generate W3C references based on the W3C publication database
    <http://www.w3.org/2002/01/tr-automation/tr.rdf>)

    Copyright (c) 2010-2012, Julian Reschke (julian.reschke@greenbytes.de)
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
               xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#"
               xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns:doc="http://www.w3.org/2000/10/swap/pim/doc#"
               xmlns:org="http://www.w3.org/2001/04/roadmap/org#"
               xmlns:r="http://www.w3.org/2001/02pd/rec54#"
               xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
               version="1.0"
               exclude-result-prefixes="contact dc doc org r rdf"
>

<xsl:output encoding="US-ASCII" omit-xml-declaration="yes" indent="yes"/>

<xsl:param name="shortname"/>
<xsl:param name="anchor"/>

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="$shortname!=''">
      <xsl:variable name="f" select="//*[contains(@rdf:about,concat('/',$shortname))]"/>
      <xsl:choose>
        <xsl:when test="count($f)=0">
          <xsl:message terminate="yes">shortname not found in publication database</xsl:message>
        </xsl:when>
        <xsl:when test="count($f)>1">
          <xsl:message terminate="yes">ambiguous match for shortname</xsl:message>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="$f">
            <xsl:call-template name="genref"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:processing-instruction name="rfc">private='W3C References'</xsl:processing-instruction>
      <xsl:processing-instruction name="rfc">sortrefs='yes'</xsl:processing-instruction>
      <xsl:processing-instruction name="rfc">symrefs='yes'</xsl:processing-instruction>
      <xsl:processing-instruction name="rfc-ext">allow-markup-in-artwork='yes'</xsl:processing-instruction>
      <xsl:processing-instruction name="rfc-ext">include-references-in-index='yes'</xsl:processing-instruction>
      <xsl:processing-instruction name="rfc-ext">check-artwork-width='no'</xsl:processing-instruction>
      <rfc>
        <front>
          <title abbrev="xml2rfc refs for W3C specs">Xml2Rfc References For W3C Specifications</title>    
          <author initials="J. F." surname="Reschke" fullname="Julian F. Reschke" role="editor">
            <organization abbrev="greenbytes">greenbytes GmbH</organization>
            <address>
              <postal>
                <street>Hafenweg 16</street>
                <city>Muenster</city><region>NW</region><code>48155</code>
                <country>Germany</country>
              </postal>
              <phone>+49 251 2807760</phone>
              <email>julian.reschke@greenbytes.de</email>
              <uri>http://greenbytes.de/tech/webdav/</uri>
            </address>
          </author>
          <date year="2012" />
       </front>
        <middle>
          <section title="Introduction">
            <t>
              Automatically generated from <eref target="http://www.w3.org/2002/01/tr-automation/tr.rdf"/> using
              <eref target="http://greenbytes.de/tech/webdav/rfc2629xslt/gen-w3c-reference.xslt"/>.
            </t>
            <t>
              Note that the ordering of authors is determined by retrieving the
              spec text and checking for the first occurance of the full author name.
              This may sometimes fail. If you find incorrect orderings, please
              notify <eref target="mailto:julian.reschke@gmx.de?subject=W3C%20author%20ordering">julian.reschke@gmx.de</eref>.
            </t>
          </section>
          <section title="&lt;reference> elements">
            <xsl:for-each select="/*/*[not(self::r:ActivityStatement or self::rdf:Description)]">
              <xsl:sort select="substring-after(substring-after(substring-after(substring-after(@rdf:about,'//'),'/'),'/'),'/')"/>
              <xsl:call-template name="genref-figures"/>
            </xsl:for-each>
          </section>
        </middle>
        <back>
          <references>
            <xsl:for-each select="/*/*[not(self::r:ActivityStatement or self::rdf:Description)]">
              <xsl:call-template name="genref"/>
            </xsl:for-each>
          </references>
        </back>
      </rfc>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="basename">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s,'/') and substring-after($s,'/')!=''">
      <xsl:call-template name="basename">
        <xsl:with-param name="s" select="substring-after($s,'/')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="translate($s,'/','')"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="genref">
  <xsl:variable name="s">
    <xsl:call-template name="basename">
      <xsl:with-param name="s" select="@rdf:about"/>
    </xsl:call-template>
  </xsl:variable>
  
  <!-- exclude a few broken ones -->
  <xsl:if test="string-length(translate(substring($s,1,1),'0123456789',''))!=0">
    <reference target="{@rdf:about}">
      <xsl:attribute name="anchor">
        <xsl:choose>
          <xsl:when test="$shortname!=''">
            <xsl:value-of select="$shortname"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$s"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <front>
        <title><xsl:value-of select="dc:title"/></title>
        <xsl:apply-templates select="r:editor/contact:fullName|r:editor/org:name"/>
        <xsl:if test="count(r:editor/contact:fullName|r:editor/org:name)=0">
          <xsl:message>No author information for <xsl:value-of select="$s"/></xsl:message>
          <author>
            <xsl:comment>author info missing</xsl:comment>
            <organization/>
          </author>
        </xsl:if>
        <date>
          <xsl:variable name="yyyy" select="substring-before(dc:date,'-')"/>
          <xsl:variable name="mmdd" select="substring-after(dc:date,'-')"/>
          <xsl:variable name="mm" select="substring-before($mmdd,'-')"/>
          <xsl:variable name="dd" select="substring-after($mmdd,'-')"/>
          <xsl:attribute name="year">
            <xsl:value-of select="$yyyy"/>
          </xsl:attribute>
          <xsl:attribute name="month">
            <xsl:call-template name="getmonth"><xsl:with-param name="mm" select="$mm"/></xsl:call-template>
          </xsl:attribute>
          <xsl:attribute name="day">
            <xsl:value-of select="$dd"/>
          </xsl:attribute>
        </date>
      </front>
      <seriesInfo>
        <xsl:attribute name="name">
          <xsl:call-template name="getseries">
            <xsl:with-param name="s" select="$s"/>
          </xsl:call-template>
        </xsl:attribute>
        <xsl:attribute name="value">
          <xsl:value-of select="$s"/>
        </xsl:attribute>
      </seriesInfo>
      <xsl:if test="doc:versionOf">
        <annotation>Latest version available at <eref target="{doc:versionOf/@rdf:resource}"/>.</annotation>
      </xsl:if>
    </reference>
  </xsl:if>
  
</xsl:template>

<xsl:template name="genref-figures">
  <xsl:variable name="s">
    <xsl:call-template name="basename">
      <xsl:with-param name="s" select="@rdf:about"/>
    </xsl:call-template>
  </xsl:variable>
  
  <!-- exclude a few broken ones -->
  <xsl:if test="string-length(translate(substring($s,1,1),'0123456789',''))!=0">
    <xsl:variable name="link">
      <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="@rdf:about"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="anchor">
      <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="$s"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="latest">
      <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="doc:versionOf/@rdf:resource"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="tseries">
      <xsl:call-template name="getseries">
        <xsl:with-param name="s" select="$s"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="series">
      <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="$tseries"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="yyyy" select="substring-before(dc:date,'-')"/>
    <xsl:variable name="mmdd" select="substring-after(dc:date,'-')"/>
    <xsl:variable name="mm" select="substring-before($mmdd,'-')"/>
    <xsl:variable name="dd" select="substring-after($mmdd,'-')"/>
    <xsl:variable name="month">
      <xsl:call-template name="getmonth"><xsl:with-param name="mm" select="$mm"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="title">
      <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="dc:title"/></xsl:call-template>
    </xsl:variable>
    
    <section title="{$s}: {dc:title}" anchor="ref-{$anchor}">
      <iref item="{$tseries}" subitem="{$s}"/>
      <xsl:apply-templates select="r:editor/contact:fullName" mode="iref">
        <xsl:with-param name="s" select="$s"/>
      </xsl:apply-templates>
      <t>
        Reference element for <xref target="{$s}"/>.
      </t>
<figure><artwork type="inline">
&lt;reference anchor='<xsl:value-of select="$anchor"/>'
           target='<xsl:value-of select="$link"/>'>
  &lt;front>
    &lt;title><xsl:value-of select="$title"/>&lt;/title>
<xsl:apply-templates select="r:editor/contact:fullName|r:editor/org:name" mode="figure"/>    &lt;date year='<xsl:value-of select="$yyyy"/>' month='<xsl:value-of select="$month"/>' day='<xsl:value-of select="$dd"/>'/>
  &lt;/front>
  &lt;seriesInfo name='<xsl:value-of select="$series"/>' value='<xsl:value-of select="$anchor"/>'/>
<xsl:if test="doc:versionOf">  &lt;annotation>
    Latest version available at
    &lt;eref target='<xsl:value-of select="$latest"/>'/>.
  &lt;/annotation>
</xsl:if>&lt;/reference>
</artwork></figure>      
      <xsl:if test="processing-instruction('sort-rdf')='alpha'">
        <t>
          <spanx>The ordering of author names above may be incorrect.</spanx>
        </t>
      </xsl:if>
    </section>
  </xsl:if>
  
</xsl:template>

<xsl:template match="contact:fullName">
  <xsl:variable name="surname">
    <xsl:call-template name="getsurname">
      <xsl:with-param name="s" select="normalize-space(.)"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="givenname" select="normalize-space(substring-before(normalize-space(.),$surname))"/>
  <xsl:variable name="initials">
    <xsl:call-template name="getinitials">
      <xsl:with-param name="s" select="$givenname"/>
    </xsl:call-template>
  </xsl:variable>
  
  <xsl:variable name="allowed">ABCDEFGHIJHKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.() -'0123456789</xsl:variable>
  
  <xsl:variable name="tmp" select="."/>
  <xsl:variable name="mapped" select="$map/map/entry[@key=$tmp]"/>
  <xsl:variable name="fn">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@fn"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$tmp"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="sn">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@surname"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$surname"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="i">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@initials"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$initials"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="translate($fn,$allowed,'')!=''">
    <xsl:message>WARNING: non-ASCII characters in <xsl:value-of select="$fn"/>: <xsl:value-of select="translate($fn,$allowed,'')"/></xsl:message>
  </xsl:if>
  <xsl:if test="translate($sn,$allowed,'')!=''">
    <xsl:message>WARNING: non-ASCII characters in <xsl:value-of select="$sn"/>: <xsl:value-of select="translate($sn,$allowed,'')"/></xsl:message>
  </xsl:if>
  <xsl:if test="translate($i,$allowed,'')!=''">
    <xsl:message>WARNING: non-ASCII characters in <xsl:value-of select="$i"/>: <xsl:value-of select="translate($i,$allowed,'')"/></xsl:message>
  </xsl:if>
  
  <author fullname="{$fn}" surname="{$sn}" initials="{normalize-space($i)}" />
</xsl:template>

<xsl:template match="contact:fullName" mode="iref">
  <xsl:param name="s"/>
  <xsl:variable name="surname">
    <xsl:call-template name="getsurname">
      <xsl:with-param name="s" select="normalize-space(.)"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="givenname" select="normalize-space(substring-before(normalize-space(.),$surname))"/>
  <xsl:variable name="initials">
    <xsl:call-template name="getinitials">
      <xsl:with-param name="s" select="$givenname"/>
    </xsl:call-template>
  </xsl:variable>
  <iref subitem="{$s}">
    <xsl:attribute name="item">
      <xsl:call-template name="filter"><xsl:with-param name="s" select="normalize-space($surname)"/></xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="filter"><xsl:with-param name="s" select="normalize-space($initials)"/></xsl:call-template>
    </xsl:attribute>
  </iref>
</xsl:template>

<xsl:template match="contact:fullName" mode="figure">
  <xsl:variable name="surname">
    <xsl:call-template name="getsurname">
      <xsl:with-param name="s" select="normalize-space(.)"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="givenname" select="normalize-space(substring-before(normalize-space(.),$surname))"/>
  <xsl:variable name="initials">
    <xsl:call-template name="getinitials">
      <xsl:with-param name="s" select="$givenname"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="tmp" select="."/>
  <xsl:variable name="mapped" select="$map/map/entry[@key=$tmp]"/>
  <xsl:variable name="fn">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@fn"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$tmp"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="sn">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@surname"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$surname"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="i">
    <xsl:choose>
      <xsl:when test="$mapped"><xsl:value-of select="$mapped/@initials"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$initials"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:text>    &lt;author fullname='</xsl:text>
  <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="$fn"/></xsl:call-template>
  <xsl:text>' surname='</xsl:text>
  <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="$sn"/></xsl:call-template>
  <xsl:text>' initials='</xsl:text>
  <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="$i"/></xsl:call-template>
  <xsl:text>'/>&#10;</xsl:text>
</xsl:template>

<xsl:template match="org:name">
  <author>
    <organization><xsl:value-of select="."/></organization>
  </author>
</xsl:template>

<xsl:template match="org:name" mode="figure">
  <xsl:text>    &lt;author>&#10;</xsl:text>
  <xsl:text>      &lt;organization></xsl:text>
  <xsl:call-template name="escapefilter"><xsl:with-param name="s" select="."/></xsl:call-template>
  <xsl:text>&lt;/organization>&#10;</xsl:text>
  <xsl:text>    &lt;/author>&#10;</xsl:text>
</xsl:template>

<xsl:variable name="editors" select="document('known-tr-editors.rdf')"/>
<xsl:variable name="map" select="document('w3c-author-map.xml')"/>

<xsl:template name="getseries">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="starts-with($s,'CR-')">W3C Candidate Recommendation</xsl:when>
    <xsl:when test="starts-with($s,'NOTE-')">W3C Group Note</xsl:when>
    <xsl:when test="starts-with($s,'PER-')">W3C Proposed Edited Recommendation</xsl:when>
    <xsl:when test="starts-with($s,'PR-')">W3C Proposed Recommendation</xsl:when>
    <xsl:when test="starts-with($s,'REC-')">W3C Recommendation</xsl:when>
    <xsl:when test="starts-with($s,'WD-')">W3C Working Draft</xsl:when>
    <xsl:otherwise>W3C ???</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="getmonth">
  <xsl:param name="mm"/>
  <xsl:choose>  
    <xsl:when test="$mm=1">January</xsl:when>
    <xsl:when test="$mm=2">Febuary</xsl:when>
    <xsl:when test="$mm=3">March</xsl:when>
    <xsl:when test="$mm=4">April</xsl:when>
    <xsl:when test="$mm=5">May</xsl:when>
    <xsl:when test="$mm=6">June</xsl:when>
    <xsl:when test="$mm=7">July</xsl:when>
    <xsl:when test="$mm=8">August</xsl:when>
    <xsl:when test="$mm=9">September</xsl:when>
    <xsl:when test="$mm=10">October</xsl:when>
    <xsl:when test="$mm=11">November</xsl:when>
    <xsl:when test="$mm=12">December</xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template name="getsurname">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="$editors//contact:lastName=$s">
      <xsl:value-of select="$s"/>
    </xsl:when>
    <xsl:when test="contains($s,' ')">
      <xsl:call-template name="getsurname">
        <xsl:with-param name="s" select="substring-after($s,' ')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="getinitials">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s,' ')">
      <xsl:value-of select="substring($s,1,1)"/><xsl:text>. </xsl:text>
      <xsl:call-template name="getinitials">
        <xsl:with-param name="s" select="substring-after($s,' ')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="substring($s,1,1)"/><xsl:text>. </xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="escapefilter">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="$s!=''">
      <xsl:variable name="apos">'</xsl:variable>
      <xsl:variable name="l" select="substring($s,1,1)"/>
      <xsl:choose>
        <xsl:when test="$l='&amp;'">
          <xsl:text>&amp;amp;</xsl:text>
        </xsl:when>
        <xsl:when test="$l='&quot;'">
          <xsl:text>&amp;quot;</xsl:text>
        </xsl:when>
        <xsl:when test="$l=$apos">
          <xsl:text>&amp;apos;</xsl:text>
        </xsl:when>
        <xsl:when test="$l='&#8482;'">
          <xsl:text>(tm)</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$l"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="escapefilter">
        <xsl:with-param name="s" select="substring($s,2)"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

<xsl:template name="filter">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="$s!=''">
      <xsl:variable name="l" select="substring($s,1,1)"/>
      <xsl:choose>
        <xsl:when test="$l='&#8482;'">
          <xsl:text>(tm)</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$l"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="filter">
        <xsl:with-param name="s" select="substring($s,2)"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

</xsl:transform>