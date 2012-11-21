<!--
    XSLT test cases

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
                version="1.0"
                xmlns:msxsl="urn:schemas-microsoft-com:xslt"
                xmlns:exslt="http://exslt.org/common"
                xmlns:date="http://exslt.org/dates-and-times"
                exclude-result-prefixes="msxsl exslt">

<xsl:output method="html" encoding="iso-8859-1" version="4.0" doctype-public="-//W3C//DTD HTML 4.01//EN" indent="no"/>

<xsl:template match="/">
  <html>
    <head>
      <title>XSLT test cases</title>
      <style type="text/css">
        body {
          font-family: verdana, helvetica, arial, sans-serif;
          font-size: 10pt;
        }
        td {
          text-align: left;
        } 
        th {
          text-align: left;
        } 
        h1 {
          font-size: 14pt;
        }
        h2 {
          font-size: 12pt;
        }
        .green {
          color: green;
        }
        .red {
          color: red;
        }
      </style>
    </head>
    <body>
      <h1>XSLT test cases</h1>
      
      <xsl:call-template name="info"/>
      <xsl:call-template name="nodeset"/>
      <xsl:call-template name="whitespace-treatment"/>
      <xsl:call-template name="date-time"/>
    </body>
  </html>
</xsl:template>

<xsl:template name="info">
  <h2 id="engine.information">Engine Information</h2>

  <table>
    <thead>
      <tr>
        <th><a href="http://www.w3.org/TR/xslt#function-system-property">System Property</a></th>
        <th>Value</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <code>
            xsl:version
          </code>
        </td>
        <td>
          <tt>
            <xsl:value-of select="system-property('xsl:version')"/>
          </tt>
        </td>
      </tr>
      <tr>
        <td>
          <code>
            xsl:vendor
          </code>
        </td>
        <td>
          <tt>
            <xsl:value-of select="system-property('xsl:vendor')"/>
          </tt>
        </td>
      </tr>
      <tr>
        <td>
          <code>
            xsl:vendor-url
          </code>
        </td>
        <td>
          <tt>
            <a href="{system-property('xsl:vendor-url')}"><xsl:value-of select="system-property('xsl:vendor-url')"/></a>
          </tt>
        </td>
      </tr>
      <tr>
        <td>
          <code>
            msxsl:version
          </code>
        </td>
        <td>
          <tt>
            <xsl:value-of select="system-property('msxsl:version')"/>
          </tt>
        </td>
      </tr>
    </tbody>
  </table>
</xsl:template>

<xsl:template name="nodeset">
  <h2 id="node-set">Node-Set Support</h2>
  
  <table>
    <thead>
      <tr>
        <th>Nodeset Extension</th>
        <th>Available?</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <code>
            <a href="http://www.exslt.org/exsl/functions/node-set/exsl.node-set.html">exslt:node-set</a>
          </code>
        </td>
        <td>
          <xsl:choose>
            <xsl:when test="function-available('exslt:node-set')">
              <div class="green">Yes</div>
            </xsl:when>
            <xsl:otherwise>
              <div class="red">No</div>
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
      <tr>
        <td>
          <code>
            <a href="http://msdn2.microsoft.com/en-us/library/ms256197.aspx">msxsl:node-set</a>
          </code>
        </td>
        <td>
          <xsl:choose>
            <xsl:when test="function-available('msxsl:node-set')">
              <div class="green">Yes</div>
            </xsl:when>
            <xsl:otherwise>
              No
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
    </tbody>
  </table>
</xsl:template>

<xsl:template name="whitespace-treatment">
  <h2 id="whitespace">Whitespace Treatment</h2>

  <p>
    Whitespace between elements is respected:
    <xsl:choose>
      <xsl:when test="/*/whitespace-test[@id='ws-def']/text()">
        <span class="green">Yes</span>
      </xsl:when>
      <xsl:otherwise>
        <span class="red">No</span>
      </xsl:otherwise>
    </xsl:choose>
  </p>
  <p>
    Whitespace between elements respected when xml:space='preserved' :
    <xsl:choose>
      <xsl:when test="/*/whitespace-test[@id='ws-pres']/text()">
        <span class="green">Yes</span>
      </xsl:when>
      <xsl:otherwise>
        <span class="red">No</span>
      </xsl:otherwise>
    </xsl:choose>
  </p>
</xsl:template>

<xsl:template name="date-time">
  <h2 id="date-time">Date-Time Support</h2>
  
  <p>
    <code>
      <a href="http://www.exslt.org/date/functions/date-time/">exslt:date-time()</a>
    </code>:
    <xsl:choose>
      <xsl:when test="function-available('date:date-time')">
        <span class="green">Yes</span>, and returns: <xsl:value-of select="date:date-time()"/>
      </xsl:when>
      <xsl:otherwise>
        <span class="red">No</span>
      </xsl:otherwise>
    </xsl:choose>
  </p>
</xsl:template>

</xsl:transform>