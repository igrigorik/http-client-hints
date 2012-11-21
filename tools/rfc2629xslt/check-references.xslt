<!--
    Check RFC references (requires local copy of "rfc-index.xml",
    available from <ftp://ftp.isi.edu/in-notes/rfc-index.xml> and
    "tr.rdf", available from <http://www.w3.org/2002/01/tr-automation/tr.rdf>)

    Copyright (c) 2006-2008, Julian Reschke (julian.reschke@greenbytes.de)
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
                version="2.0"
                xmlns:ed="http://greenbytes.de/2002/rfcedit"
                xmlns:rfced="http://www.rfc-editor.org/rfc-index"
                xmlns:x="http://purl.org/net/xml2rfc/ext"
>

<xsl:output method="text" encoding="UTF-8"/>

<xsl:param name="intended-level">
  <xsl:choose>
    <xsl:when test="/rfc/@x:maturity-level"><xsl:value-of select="/rfc/@x:maturity-level"/></xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:param>

<xsl:param name="link-check" />

<xsl:template match="/">
  <xsl:if test="$intended-level!='' and ($intended-level!='proposed' and $intended-level!='draft' and $intended-level!='internet')">
    <xsl:message terminate='yes'>intended-level: unsupported value (must be 'proposed', 'draft' or 'internet')!</xsl:message>
  </xsl:if>
  
  <xsl:if test="$link-check!='' and ($link-check!='no' and $link-check!='yes')">
    <xsl:message terminate='yes'>link-check: unsupported value (must be 'yes' or 'no')!</xsl:message>
  </xsl:if>

  <xsl:for-each select="//references">
    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="@title">
          <xsl:value-of select="@title"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>References</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text>&#10;</xsl:text>
    <xsl:value-of select="$title"/>
    <xsl:text>:&#10;</xsl:text>
    <xsl:for-each select=".//reference[not(ancestor::ed:del)]">
      <xsl:sort select="@anchor"/>
      
      <xsl:choose>
        <xsl:when test="seriesInfo/@name='RFC'">
          <xsl:apply-templates select="." mode="check-rfc"/>
        </xsl:when>
        <xsl:when test="(seriesInfo/@name='ID' or seriesInfo/@name='Internet-Draft') and starts-with(seriesInfo/@value,'draft-')">
          <xsl:apply-templates select="." mode="check-internet-draft"/>
        </xsl:when>
        <xsl:when test="(seriesInfo/@name='W3C' or starts-with(seriesInfo/@name, 'W3C ') or starts-with(seriesInfo/@name, 'World Wide Web Consortium'))">
          <xsl:apply-templates select="." mode="check-w3c"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@anchor"/>
          <xsl:text>: not checked&#10;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:for-each>

  <xsl:variable name="targets2" select="//eref/@target | //reference/@target"/>
  <xsl:variable name="targets" select="$targets2[starts-with(.,'http')]"/>
  <xsl:if test="$targets and $link-check='yes'">
    <xsl:text>&#10;Link Targets&#10;</xsl:text>
    <xsl:choose>
      <xsl:when test="function-available('unparsed-text-available')">
        <xsl:for-each select="$targets">
          <xsl:variable name="t">
            <xsl:choose>
              <xsl:when test="contains(.,'#')"><xsl:value-of select="substring-before(.,'#')"/></xsl:when>
              <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
        
          <xsl:text>&lt;</xsl:text>
          <xsl:value-of select="$t"/>
          <xsl:text>&gt;: </xsl:text>
          <xsl:choose>
            <xsl:when test="unparsed-text-available($t)">ok</xsl:when>
            <xsl:otherwise>NOT AVAILABLE AS TEXT</xsl:otherwise>
          </xsl:choose>
          <xsl:text>&#10;</xsl:text>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>not checked (requires XSLT 2.0)</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
  
</xsl:template>

<!-- helper -->
<xsl:template name="base-name">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s,'/') and substring-after($s,'/')!=''">
      <xsl:call-template name="base-name">
        <xsl:with-param name="s" select="substring-after($s,'/')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="translate($s,'/','')"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- check RFC reference -->
<xsl:template match="reference" mode="check-rfc">
  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="ancestor::references/@title">
        <xsl:value-of select="ancestor::references/@title"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>References</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="no" select="seriesInfo[@name='RFC']/@value" />
  <xsl:variable name="id" select="concat('RFC',substring('000',string-length($no)),$no)" />
  <xsl:value-of select="$id" />
  <xsl:text>: </xsl:text>
  <xsl:variable name="stat" select="document('rfc-index.xml')/*/rfced:rfc-entry[rfced:doc-id=$id]" />
  <xsl:if test="$stat/rfced:current-status">
    <xsl:text>[</xsl:text><xsl:value-of select="$stat/rfced:current-status"/><xsl:text>] </xsl:text>
  </xsl:if> 
  <xsl:if test="$stat/rfced:is-also">
    <xsl:text>(-> </xsl:text><xsl:value-of select="$stat/rfced:is-also/rfced:doc-id"/><xsl:text>) </xsl:text>
  </xsl:if> 
  <xsl:choose>
    <xsl:when test="$stat/rfced:obsoleted-by">
      <xsl:text>obsoleted by </xsl:text>
      <xsl:for-each select="$stat/rfced:obsoleted-by/rfced:doc-id">
        <xsl:value-of select="."/>
        <xsl:text> </xsl:text>
      </xsl:for-each>
    </xsl:when>
    <xsl:when test="not($stat)">not found in RFC index!</xsl:when>

    <!-- check the status of the normatively referred drafts -->
    <xsl:when test="$intended-level='proposed' and ($title='References' or $title='Normative References') and
      ($stat/rfced:publication-status='PROPOSED STANDARD' or $stat/rfced:publication-status='DRAFT STANDARD' or $stat/rfced:publication-status='STANDARD' or $stat/rfced:publication-status='BEST CURRENT PRACTICE')">
      <!-- ok -->
    </xsl:when>
    <xsl:when test="$intended-level='draft' and ($title='References' or $title='Normative References') and
      ($stat/rfced:publication-status='DRAFT STANDARD' or $stat/rfced:publication-status='STANDARD' or $stat/rfced:publication-status='BEST CURRENT PRACTICE')">
      <!-- ok -->
    </xsl:when>
    <xsl:when test="$intended-level='internet' and ($title='References' or $title='Normative References') and
      ($stat/rfced:publication-status='STANDARD' or $stat/rfced:publication-status='BEST CURRENT PRACTICE')">
      <!-- ok -->
    </xsl:when>
    <xsl:when test="$intended-level!='' and ($title='References' or $title='Normative References')">
      <xsl:text>-- intended standards level of </xsl:text>
      <xsl:value-of select="$intended-level"/>
      <xsl:text> incompatible with this document's standard level</xsl:text>
      <xsl:if test="annotation//xref[@target='BCP97']">
        <xsl:text> (...but a downref annotation referencing BCP 97 seems to be present)</xsl:text>
      </xsl:if>
      <xsl:text>!</xsl:text>
    </xsl:when>
    <xsl:otherwise>ok</xsl:otherwise>
  </xsl:choose>
  <xsl:text>&#10;</xsl:text>    
</xsl:template>

<!-- check Internet Draft reference, experimental -->
<xsl:template match="reference" mode="check-internet-draft">
  <xsl:variable name="name" select="seriesInfo[(@name='ID' or @name='Internet-Draft') and starts-with(@value,'draft-')]/@value" />
  <xsl:value-of select="$name" />
  <xsl:text>: </xsl:text>
  <xsl:variable name="base" select="substring($name,1,string-length($name)-3)"/>
  <xsl:variable name="number" select="substring($name,string-length($name)-1)"/>
  <xsl:variable name="stat" select="document(concat('http://tools.ietf.org/draft/',$base,'/state.xml'))" />
  
  <!--stat: <xsl:value-of select="$stat/ietfdoc/info/rev"/>
  number: <xsl:value-of select="$number"/>-->
  
  <xsl:choose>
    <xsl:when test="$stat/ietfdoc/info/rev != $number">
      <xsl:text>Alternate version available: </xsl:text><xsl:value-of select="$stat/ietfdoc/info/rev"/>
      <xsl:if test="$stat/ietfdoc[state/phase='Published']">
        <xsl:text>, later published as: RFC</xsl:text><xsl:value-of select="$stat/ietfdoc/info/rfcnum"/>
      </xsl:if>
    </xsl:when>
    <xsl:when test="$stat/ietfdoc[state/phase='Published']">
      <xsl:value-of select="concat('(-> RFC',$stat/ietfdoc/info/rfcnum,')')"/>
    </xsl:when>
    <xsl:when test="$stat/ietfdoc/state[phase='IESG' or phase='RFC-Editor']">
      <xsl:value-of select="concat('[',$stat/ietfdoc/state/phase/@ts,' ',$stat/ietfdoc/state/phase,'] ok')"/>
    </xsl:when>
    <xsl:when test="$stat/ietfdoc[state/phase='ID-Exists' and info/validity='Active']">
      <xsl:value-of select="concat('[',$stat/ietfdoc/state/phase/@ts,' ',$stat/ietfdoc/state/phase,'] ok')"/>
    </xsl:when>
    <xsl:when test="$stat/ietfdoc[info/validity!='Active']">
      <xsl:value-of select="concat('[',$stat/ietfdoc/state/phase/@ts,' ',$stat/ietfdoc/state/phase,' ',$stat/ietfdoc/info/validity,'] (not active)')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>ID does not exist</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:text>&#10;</xsl:text>        
</xsl:template>

<xsl:template match="reference" mode="check-internet-draft-old">
  <xsl:variable name="name" select="seriesInfo[(@name='ID' or @name='Internet-Draft') and starts-with(@value,'draft-')]/@value" />
  <xsl:value-of select="$name" />
  <xsl:text>: </xsl:text>
  <xsl:variable name="stat" select="document('ietf-id-status.xml')/*/draft[@xml:id=$name]" />
  <xsl:choose>
    <xsl:when test="$stat[@status='active' or @status='IESG']">
      <xsl:value-of select="concat('[',$stat/@date,' ',$stat/@status,'] ok')"/>
    </xsl:when>
    <xsl:when test="$stat[@status='RFC']">
      <xsl:value-of select="concat('[',$stat/@date,' ',$stat/@status,'] (-> RFC',$stat/@num,')')"/>
    </xsl:when>
    <xsl:when test="$stat[@status='expired']">
      <xsl:value-of select="concat('[',$stat/@date,' ',$stat/@status,'] expired!')"/>
    </xsl:when>
    <xsl:when test="$stat">
      <xsl:value-of select="concat('[',$stat/@date,' ',$stat/@status,'] UNKNOWN STATUS!')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="base" select="substring($name,1,string-length($name)-3)"/>
      <xsl:variable name="stat2" select="document('ietf-id-status.xml')/*/draft[starts-with(@xml:id,$base)]" />
      <xsl:choose>
        <xsl:when test="$stat2">
          <xsl:text>Alternate version available: </xsl:text><xsl:value-of select="$stat2/@xml:id"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>ID does not exist</xsl:text>
        </xsl:otherwise>
      </xsl:choose>     
    </xsl:otherwise>
  </xsl:choose>
  <xsl:text>&#10;</xsl:text>        
</xsl:template>

<!-- check W3C reference -->
<xsl:template match="reference" mode="check-w3c" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:doc="http://www.w3.org/2000/10/swap/pim/doc#"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:pd="http://www.w3.org/2001/02pd/rec54#">
  <xsl:variable name="w3c" select="document('tr.rdf')"/>
  <xsl:variable name="name" select="seriesInfo/@value" />
  <xsl:value-of select="$name" />
  <xsl:text>: </xsl:text>
  <xsl:variable name="stat">
    <xsl:for-each select="$w3c/*/*">
      <xsl:variable name="t">
        <xsl:call-template name="base-name">
          <xsl:with-param name="s" select="@rdf:about"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$t=$name">
        <xsl:value-of select="concat(@rdf:about,' ')"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="contains(normalize-space($stat),' ')">
      <xsl:text>ambiguous match: </xsl:text><xsl:value-of select="$stat"/>
    </xsl:when>
    <xsl:when test="$stat!=''">
      <xsl:variable name="basename" select="normalize-space($stat)"/>
      <xsl:variable name="doc" select="$w3c/*/*[@rdf:about=$basename]"/>
      <xsl:value-of select="concat('[',local-name($doc),'] ')"/>
      <xsl:variable name="previous" select="$w3c/*/*[pd:previousEdition/@rdf:resource=$basename]"/>
      <xsl:choose>
        <xsl:when test="$previous">
          <xsl:text>obsoleted by</xsl:text>
          <xsl:for-each select="$previous">
            <xsl:sort select="translate(dc:date,'-','')"/>
            <xsl:if test="position()=last()">
              <xsl:text> </xsl:text>
              <xsl:call-template name="base-name">
                <xsl:with-param name="s" select="@rdf:about"/>
              </xsl:call-template>
            </xsl:if>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>ok</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>document unknown</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:text>&#10;</xsl:text>        
</xsl:template>

</xsl:transform>