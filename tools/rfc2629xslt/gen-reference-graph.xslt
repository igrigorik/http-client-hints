<!--
    Gen reference graph (requires local copy of "rfc-index.xml",
    available from <ftp://ftp.isi.edu/in-notes/rfc-index.xml> and
    "tr.rdf", available from <http://www.w3.org/2002/01/tr-automation/tr.rdf>)

    Copyright (c) 2006-2007, Julian Reschke (julian.reschke@greenbytes.de)
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
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:doc="http://www.w3.org/2000/10/swap/pim/doc#"
                xmlns:ed="http://greenbytes.de/2002/rfcedit"
                xmlns:exslt="http://exslt.org/common"
                xmlns:msxsl="urn:schemas-microsoft-com:xslt"
                xmlns:rfced="http://www.rfc-editor.org/rfc-index"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:tr="http://www.w3.org/2001/02pd/rec54#"
>

<xsl:output method="text" encoding="UTF-8"/>

<!-- character translation tables -->
<xsl:variable name="lcase" select="'abcdefghijklmnopqrstuvwxyz'" />
<xsl:variable name="ucase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />

<!-- define exslt:node-set for msxml -->       
<msxsl:script language="JScript" implements-prefix="exslt">
  this['node-set'] = function (x) {
    return x;
  }
</msxsl:script>

<xsl:template match="/">
  <xsl:text>digraph </xsl:text>
  <xsl:value-of select="translate(/rfc/@docName,'-.','__')" />
  <xsl:text> { &#10;</xsl:text>
  <xsl:text>  rankdir=LR;</xsl:text>

  <xsl:variable name="out">
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
      <xsl:for-each select=".//reference[not(ancestor::ed:del)]">
        <xsl:sort select="@anchor"/>
        <xsl:choose>
          <xsl:when test="seriesInfo/@name='RFC'">
            <xsl:apply-templates select="." mode="check-rfc"/>
          </xsl:when>
          <xsl:when test="seriesInfo/@name='Internet-Draft'">
            <!-- Nothing to do -->
          </xsl:when>
          <xsl:when test="seriesInfo/@name='W3C'">
            <xsl:call-template name="check-w3c">
              <xsl:with-param name="serinfo" select="seriesInfo[@name='W3C']"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="seriesInfo/@name='W3C NOTE'">
            <xsl:message>Warning: seriesInfo/@name for W3C specs should be 'W3C', found: 'W3C NOTE'.</xsl:message>
            <xsl:call-template name="check-w3c">
              <xsl:with-param name="serinfo" select="seriesInfo[@name='W3C NOTE']"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="seriesInfo/@name='W3C REC'">
            <xsl:message>Warning: seriesInfo/@name for W3C specs should be 'W3C', found: 'W3C REC'.</xsl:message>
            <xsl:call-template name="check-w3c">
              <xsl:with-param name="serinfo" select="seriesInfo[@name='W3C REC']"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="seriesInfo/@name='World Wide Web Consortium FirstEdition'">
            <xsl:message>Warning: seriesInfo/@name for W3C specs should be 'W3C', found: 'World Wide Web Consortium FirstEdition'.</xsl:message>
            <xsl:call-template name="check-w3c">
              <xsl:with-param name="serinfo" select="seriesInfo[@name='World Wide Web Consortium FirstEdition']"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="seriesInfo/@name='World Wide Web Consortium Recommendation'">
            <xsl:message>Warning: seriesInfo/@name for W3C specs should be 'W3C', found: 'World Wide Web Consortium Recommendation'.</xsl:message>
            <xsl:call-template name="check-w3c">
              <xsl:with-param name="serinfo" select="seriesInfo[@name='World Wide Web Consortium Recommendation']"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="seriesInfo/@name">
            <xsl:message>Warning: unknown seriesInfo/@name: '<xsl:value-of select="seriesInfo/@name"/>'. </xsl:message>
          </xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:for-each select="exslt:node-set($out)/definition">
    <xsl:if test="not(@id = preceding-sibling::definition/@id)">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:for-each>
  <xsl:for-each select="exslt:node-set($out)/relation">
    <xsl:if test="not(. = preceding-sibling::relation)">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:for-each>

  <xsl:text>}&#10;</xsl:text>
</xsl:template>

<xsl:template name="write-rfc-node-def">
  <xsl:param name="node"/>
  <xsl:variable name="boxstyle">
    <xsl:choose>
      <xsl:when test="$node/rfced:current-status='BEST CURRENT PRACTICE'">
        <xsl:text>[style = filled, fillcolor = black, fontcolor=white, shape=box]</xsl:text>
      </xsl:when>
      <xsl:when test="$node/rfced:current-status='INFORMATIONAL'">
        <xsl:text>[style = filled, fillcolor = blue]</xsl:text>
      </xsl:when>
      <xsl:when test="$node/rfced:current-status='EXPERIMENTAL'">
        <xsl:text>[style = filled, fillcolor = cyan]</xsl:text>
      </xsl:when>
      <xsl:when test="$node/rfced:current-status='PROPOSED STANDARD'">
        <xsl:text>[style = "filled,rounded", fillcolor = yellow, shape=box]</xsl:text>
      </xsl:when>
      <xsl:when test="$node/rfced:current-status='DRAFT STANDARD'">
        <xsl:text>[style = "filled,rounded", fillcolor = orange, shape=box]</xsl:text>
      </xsl:when>
      <xsl:when test="$node/rfced:current-status='STANDARD'">
        <xsl:text>[style = "filled,rounded", fillcolor = green, shape=box]</xsl:text>
      </xsl:when>
      <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <definition id="{$node/rfced:doc-id}">
    <xsl:text>  "</xsl:text>
    <xsl:value-of select="$node/rfced:doc-id"/>
    <xsl:text>" [URL = "</xsl:text>
    <xsl:value-of select="concat('http://tools.ietf.org/html/',translate($node/rfced:doc-id,$ucase,$lcase))"/>
    <xsl:text>"][tooltip = "</xsl:text>
    <xsl:value-of select="$node/rfced:title"/>
    <xsl:text>"]</xsl:text>
    <xsl:value-of select="$boxstyle"/>
    <xsl:text>;&#10;</xsl:text>
  </definition>
</xsl:template>

<xsl:template name="write-w3c-node-def">
  <xsl:param name="node"/>
  <xsl:param name="doc-id"/>
  <xsl:variable name="boxstyle">
    <xsl:choose>
      <xsl:when test="local-name($node) = 'NOTE'">
        <xsl:text>[style = filled, fillcolor = blue]</xsl:text>
      </xsl:when>
      <xsl:when test="local-name($node) = 'FirstEdition'">
        <xsl:text>[style = "filled,rounded", fillcolor = green, shape=box]</xsl:text>
      </xsl:when>
      <xsl:when test="local-name($node) = 'PER'">
        <xsl:text>[style = "filled,rounded", fillcolor = yellow, shape=box]</xsl:text>
      </xsl:when>
      <xsl:when test="local-name($node) = 'REC'">
        <xsl:text>[style = "filled,rounded", fillcolor = green, shape=box]</xsl:text>
      </xsl:when>
      <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <definition id="{$doc-id}">
    <xsl:text>  "</xsl:text>
    <xsl:value-of select="$doc-id"/>
    <xsl:text>" [URL = "</xsl:text>
    <xsl:value-of select="$node/@rdf:about"/>
    <xsl:text>"][tooltip = "</xsl:text>
    <xsl:value-of select="$node/dc:title"/>
    <xsl:text>"]</xsl:text>
    <xsl:value-of select="$boxstyle"/>
    <xsl:text>;&#10;</xsl:text>
  </definition>
</xsl:template>

<!-- check an RFC Index entry -->
<xsl:template name="check-rfc-index-entry">
  <xsl:param name="src-id"/>
  <xsl:param name="doc-id"/>
  <xsl:param name="title"/>

  <xsl:variable name="stat" select="document('rfc-index.xml')/*/rfced:rfc-entry[rfced:doc-id=$doc-id]" />

  <xsl:if test="$stat/rfced:doc-id">
    <xsl:call-template name="write-rfc-node-def">
      <xsl:with-param name="node" select="$stat"/>
    </xsl:call-template>
  </xsl:if>

  <xsl:if test="$src-id">
    <relation>
      <xsl:text>  "</xsl:text>
      <xsl:value-of select="$src-id"/>
      <xsl:text>" -> "</xsl:text>
      <xsl:value-of select="$doc-id"/>
      <xsl:choose>
        <xsl:when test="$title='References' or $title='Normative References'">
          <xsl:text>" [style = solid, color = red][tooltip = "normatively references"];&#10;</xsl:text>
        </xsl:when>
        <xsl:when test="$title!=''">
          <xsl:text>" [style = solid][tooltip = "informatively references"];&#10;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>" [style = solid][tooltip = "references"];&#10;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </relation>
  </xsl:if>
  
  <xsl:for-each select="$stat/rfced:updated-by/rfced:doc-id">
    <xsl:call-template name="check-rfc-index-entry">
      <xsl:with-param name="doc-id" select="."/>
    </xsl:call-template>
    <relation>
      <xsl:text>  "</xsl:text>
      <xsl:value-of select="$doc-id"/>
      <xsl:text>" -> "</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>" [style = dotted, dir = back, tooltip = "updates"];&#10;</xsl:text>
    </relation>
  </xsl:for-each>
  <xsl:for-each select="$stat/rfced:obsoleted-by/rfced:doc-id">
    <xsl:call-template name="check-rfc-index-entry">
      <xsl:with-param name="doc-id" select="."/>
    </xsl:call-template>
    <relation>
      <xsl:text>  "</xsl:text>
      <xsl:value-of select="$doc-id"/>
      <xsl:text>" -> "</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>" [style = dashed, dir = back, tooltip = "obsoletes"];&#10;</xsl:text>
    </relation>
  </xsl:for-each>
  
</xsl:template>

<!-- check a W3C Index entry -->
<xsl:template name="check-w3c-index-entry">
  <xsl:param name="src-id"/>
  <xsl:param name="doc-id"/>
  <xsl:param name="title"/>

  <xsl:variable name="stat" select="document('tr.rdf')//*[substring(@rdf:about, string-length(@rdf:about) - string-length($doc-id) + 1) = $doc-id
    or substring(@rdf:about, string-length(@rdf:about) - string-length($doc-id)) = concat($doc-id,'/')]" />

  <xsl:if test="$stat">
    <xsl:call-template name="write-w3c-node-def">
      <xsl:with-param name="node" select="$stat"/>
      <xsl:with-param name="doc-id" select="$doc-id"/>
    </xsl:call-template>
  </xsl:if>

  <xsl:if test="$src-id">
    <relation>
      <xsl:text>  "</xsl:text>
      <xsl:value-of select="$src-id"/>
      <xsl:text>" -> "</xsl:text>
      <xsl:value-of select="$doc-id"/>
      <xsl:choose>
        <xsl:when test="$title='References' or $title='Normative References'">
          <xsl:text>" [style = solid, color = red][tooltip = "normatively references"];&#10;</xsl:text>
        </xsl:when>
        <xsl:when test="$title!=''">
          <xsl:text>" [style = solid][tooltip = "informatively references"];&#10;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>" [style = solid][tooltip = "references"];&#10;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </relation>
  </xsl:if>
  
  <xsl:for-each select="document('tr.rdf')//*[tr:previousEdition/@rdf:resource=$stat/@rdf:about]">
    <xsl:variable name="ref-short-name">
      <xsl:call-template name="last-segment">
        <xsl:with-param name="s" select="@rdf:about"/>
      </xsl:call-template>
    </xsl:variable>
<!--<xsl:message><xsl:value-of select="./@rdf:about"/> is a previous version of <xsl:value-of select="$stat/@rdf:about"/></xsl:message>-->
    <xsl:call-template name="check-w3c-index-entry">
      <xsl:with-param name="doc-id" select="$ref-short-name"/>
    </xsl:call-template>
    <relation>
      <xsl:text>  "</xsl:text>
      <xsl:value-of select="$doc-id"/>
      <xsl:text>" -> "</xsl:text>
      <xsl:value-of select="$ref-short-name"/>
      <xsl:text>" [style = dashed, dir = back, tooltip = "obsoletes"];&#10;</xsl:text>
    </relation>
  </xsl:for-each>
</xsl:template>

<xsl:template name="last-segment">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s,'/')">
      <xsl:choose>
        <xsl:when test="concat(substring-before($s,'/'),'/') = $s">
          <xsl:value-of select="substring-before($s,'/')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="last-segment">
            <xsl:with-param name="s" select="substring-after($s,'/')"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- check RFC reference -->
<xsl:template match="reference" mode="check-rfc">
  <xsl:variable name="no" select="seriesInfo[@name='RFC']/@value" />
  <xsl:variable name="id" select="concat('RFC',substring('000',string-length($no)),$no)" />
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
  
  <xsl:if test="/rfc/@docName">
    <xsl:call-template name="check-rfc-index-entry">
      <xsl:with-param name="src-id" select="/rfc/@docName"/>
      <xsl:with-param name="doc-id" select="$id"/>
      <xsl:with-param name="title" select="$title"/>
    </xsl:call-template>
  </xsl:if>
  <xsl:if test="/rfc/@number">
    <xsl:call-template name="check-rfc-index-entry">
      <xsl:with-param name="src-id" select="concat('RFC',/rfc/@number)"/>
      <xsl:with-param name="doc-id" select="$id"/>
      <xsl:with-param name="title" select="$title"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<!-- check W3C reference -->
<xsl:template name="check-w3c">
  <xsl:param name="serinfo"/>
  <xsl:variable name="short-name">
    <xsl:choose>
      <xsl:when test="starts-with($serinfo/@value,'W3C.')">
        <xsl:message>WARNING: seriesInfo/@value should be a valid 'short name', such as 'REC-webarch-20041215', found: '<xsl:value-of select="$serinfo/@value"/>'.</xsl:message>
        <xsl:value-of select="substring-after($serinfo/@value,'W3C.')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$serinfo/@value"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

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
  
  <xsl:if test="/rfc/@docName">
    <xsl:call-template name="check-w3c-index-entry">
      <xsl:with-param name="src-id" select="/rfc/@docName"/>
      <xsl:with-param name="doc-id" select="$short-name"/>
      <xsl:with-param name="title" select="$title"/>
    </xsl:call-template>
  </xsl:if>
  <xsl:if test="/rfc/@number">
    <xsl:call-template name="check-w3c-index-entry">
      <xsl:with-param name="src-id" select="concat('RFC',/rfc/@number)"/>
      <xsl:with-param name="doc-id" select="$short-name"/>
      <xsl:with-param name="title" select="$title"/>
    </xsl:call-template>
  </xsl:if>
  
</xsl:template>

</xsl:transform>