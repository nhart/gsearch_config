﻿<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
  xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
    		exclude-result-prefixes="exts"
  xmlns:zs="http://www.loc.gov/zing/srw/"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
  xmlns:rel="info:fedora/fedora-system:def/relations-external#"
  xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
  xmlns:fedora-model="info:fedora/fedora-system:def/model#"
  xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
  xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
  xmlns:eaccpf="urn:isbn:1-931666-33-4"
  xmlns:res="http://www.w3.org/2001/sw/DataAccess/rf1/result"
  xmlns:xalan="http://xml.apache.org/xalan"
  xmlns:xlink="http://www.w3.org/1999/xlink">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <!--<xsl:include href="file:///usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/common/basicFJMToSolr.xslt"/>-->
  <xsl:include href="file:///usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/common/escape_xml.xslt"/>
  <xsl:include href="file:///usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/common/mods_to_solr_fields.xslt"/>

  <xsl:param name="REPOSITORYNAME" select="repositoryName"/>
  <xsl:param name="FEDORASOAP" select="repositoryName"/>
  <xsl:param name="FEDORAUSER" select="repositoryName"/>
  <xsl:param name="FEDORAPASS" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>

  <!-- Test of adding explicit parameters to indexing -->
  <xsl:param name="EXPLICITPARAM1" select="defaultvalue1"/>
  <xsl:param name="EXPLICITPARAM2" select="defaultvalue2"/>
<!--
	 This xslt stylesheet generates the IndexDocument consisting of IndexFields
     from a FOXML record. The IndexFields are:
       - from the root element = PID
       - from foxml:property   = type, state, contentModel, ...
       - from oai_dc:dc        = title, creator, ...
     The IndexDocument element gets a PID attribute, which is mandatory,
     while the PID IndexField is optional.
     Options for tailoring:
       - IndexField types, see Lucene javadoc for Field.Store, Field.Index, Field.TermVector
       - IndexField boosts, see Lucene documentation for explanation
       - IndexDocument boosts, see Lucene documentation for explanation
       - generation of IndexFields from other XML metadata streams than DC
         - e.g. as for uvalibdesc included above and called below, the XML is inline
         - for not inline XML, the datastream may be fetched with the document() function,
           see the example below (however, none of the demo objects can test this)
       - generation of IndexFields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
         - from datastream by sequence of mimetypes,
           text fetched from the first mimetype that can be handled,
           default sequence given in properties.
-->

  <xsl:template match="/">
    <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
    <add>
      <!-- The following allows only active FedoraObjects to be indexed. -->
      <xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state']">
        <xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP' or @ID='DS-COMPOSITE-MODEL'])">
           <xsl:if test="starts-with($PID, 'ir')">
             <doc>
               <xsl:apply-templates select="/foxml:digitalObject" mode="activeFedoraObject">
                 <xsl:with-param name="PID" select="$PID"/>
               </xsl:apply-templates>
             </doc>
           </xsl:if>
        </xsl:if>
      </xsl:if>
    </add>
  </xsl:template>

  <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
    <xsl:param name="PID"/>

    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    
    <xsl:apply-templates select="foxml:objectProperties/foxml:property"/>

    <!-- index DC -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
      <xsl:with-param name="prefix">dc.</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

    <!-- Index the Rels-ext (using match="rdf:RDF") -->
    <xsl:apply-templates select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF">
      <xsl:with-param name="prefix">rels_</xsl:with-param>
      <xsl:with-param name="suffix">_ms</xsl:with-param>
    </xsl:apply-templates>

     <!-- Names and Roles -->
    <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="default"/>
    <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="ceacs"/>
    
    <!-- store an escaped copy of MODS... -->
    <xsl:if test="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods">
      <field name="mods_fullxml_store">
        <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="escape"/>
      </field>
    </xsl:if>

    <xsl:apply-templates select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
      <xsl:with-param name="pid" select="$PID"/>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="fjm" select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
      <xsl:with-param name="pid" select="$PID"/>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:for-each select="foxml:datastream[@ID][foxml:datastreamVersion[last()]]">
        <xsl:choose>
          <!-- Don't bother showing some... -->
          <xsl:when test="@ID='AUDIT'"></xsl:when>
          <xsl:when test="@ID='DC'"></xsl:when>
          <xsl:when test="@ID='ENDNOTE'"></xsl:when>
          <xsl:when test="@ID='MODS'"></xsl:when>
          <xsl:when test="@ID='RIS'"></xsl:when>
          <xsl:when test="@ID='SWF'"></xsl:when>
          <xsl:otherwise>
            <field name="fedora_datastreams_ms">
              <xsl:value-of select="@ID"/>
            </field>
          </xsl:otherwise>
        </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- XXX: not really liking this... creating a couple fields from the MODS
     which didn't exist due to indexing changes -->
  <xsl:template match="mods:mods" mode="ceacs">
    <xsl:for-each select="mods:originInfo/mods:dateIssued[1]">
      <xsl:variable name="textValue" select="normalize-space(text())"/>
      <xsl:if test="$textValue">
        <xsl:variable name="date">
          <xsl:call-template name="get_ISO8601_date">
            <!-- currently in basicFJMToSolr -->
            <xsl:with-param name="date" select="$textValue"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="normalize-space($date)">
            <field name="mods_dateIssued_dt">
              <xsl:value-of select="normalize-space($date)"/>
            </field>
          </xsl:when>
          <xsl:otherwise>
            <field name="mods_dateIssued_mlt">
               <xsl:value-of select="$textValue"/>
            </field>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </xsl:for-each>

    <xsl:for-each select="mods:name">
      <xsl:variable name="name_temp">
        <xsl:call-template name="name_parts_given_last">
          <xsl:with-param name="node" select="current()"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="name" select="normalize-space($name_temp)"/>
      <xsl:if test="$name">
        <field name="mods_rname_associated_ms">
          <xsl:value-of select="$name"/>
        </field>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="/foxml:digitalObject" mode="inactiveFedoraObject">
    <xsl:param name="PID"/>
    
    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
  <xsl:template match="/foxml:digitalObject" mode="deletedFedoraObject">
    <xsl:param name="PID"/>

    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
  <xsl:template match="foxml:property">
    <xsl:param name="prefix">fgs_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>
    <xsl:param name="date_suffix">_dt</xsl:param>
    
    <xsl:variable name="name" select="substring-after(@NAME,'#')"/>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, $name, $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="@VALUE"/>
    </field>
    
    <xsl:if test="$name='lastModifiedDate' or $name='createdDate'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, $name, $date_suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@VALUE"/>
      </field>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="rdf:RDF">
    <xsl:param name="prefix">rels_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>

    <xsl:for-each select=".//rdf:Description/*[@rdf:resource]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_uri', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@rdf:resource"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select=".//rdf:Description/*[not(@rdf:resource)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_literal', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>

  <!-- Basic EAC-CPF -->
  <xsl:template match="eaccpf:eac-cpf">
        <xsl:param name="pid"/>
        <xsl:param name="dsid" select="'EAC-CPF'"/>
        <xsl:param name="prefix" select="'eaccpf_'"/>
        <xsl:param name="suffix" select="'_et'"/> <!-- 'edged' (edge n-gram) text, for auto-completion -->

        <xsl:variable name="cpfDesc" select="eaccpf:cpfDescription"/>
        <xsl:variable name="identity" select="$cpfDesc/eaccpf:identity"/>
        <xsl:variable name="name_prefix" select="concat($prefix, 'name_')"/>
        <!-- ensure that the primary is first -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[@localType='primary']">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>

        <!-- place alternates (non-primaries) later -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[not(@localType='primary')]">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
    </xsl:template>

  <xsl:template match="eaccpf:nameEntry">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_name_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>

    <!-- fore/first name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'given', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="part[@localType='middle']">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(eaccpf:part[@localType='forename'])"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>
    
    <!-- sur/last name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'family', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(eaccpf:part[@localType='surname'])"/>
    </field>
    
    <!-- id -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'id', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:value-of select="concat($pid, '/', @id)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($pid,'/name_position:', position())"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>

    <!-- full/complete name -->
    <xsl:variable name="full_name">
      <xsl:choose>
        <xsl:when test="normalize-space(part[@localType='middle'])">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename']))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'complete', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="$full_name"/>
    </field>
    
    <!-- create sortable copy -->
    <xsl:if test="@localType='primary'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'complete', '_es')"/>
        </xsl:attribute>
        <xsl:value-of select="$full_name"/>
      </field>
    </xsl:if>
  </xsl:template>

  <xsl:template match="eaccpf:eac-cpf" mode="fjm">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>
    
    <xsl:variable name="TN_TF">
      <xsl:call-template name="perform_query">
        <xsl:with-param name="lang">sparql</xsl:with-param>
        <xsl:with-param name="query">
PREFIX ir-rel: &lt;http://digital.march.es/ceacs#&gt;
SELECT $tn_pid
WHERE {
  $tn_pid ir-rel:iconOf &lt;info:fedora/<xsl:value-of select="$pid"/>&gt;
}
        </xsl:with-param>
      </xsl:call-template>
    </xsl:variable>
    <xsl:for-each select="xalan:nodeset($TN_TF)/res:sparql/res:results/res:result[1]/res:tn_pid">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'thumbnail_object', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="substring-after(@uri, '/')"/>
      </field>
    </xsl:for-each>
    
    <xsl:for-each select='(eaccpf:cpfDescription/eaccpf:relations/eaccpf:resourceRelation[eaccpf:descriptiveNote/eaccpf:p/text()="Academic page"])[1]'>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'academic_page', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@xlink:href"/>
      </field>
    </xsl:for-each>
    
    <xsl:for-each select='(eaccpf:cpfDescription/eaccpf:relations/eaccpf:cpfRelation[starts-with(eaccpf:relationEntry/text(), "Institute Juan March")])[1]'>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'ceacs_member', '_b')"/>
        </xsl:attribute>
        <xsl:text>true</xsl:text>
      </field>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'ceacs_role', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="normalize-space(eaccpf:relationEntry/text())"/>
        
        <xsl:variable name="dateInfo">
          <xsl:choose>
            <xsl:when test="substring(eaccpf:relationEntry/text(), string-length(eaccpf:relationEntry/text()) - 3, 'PhD')">
              <xsl:value-of select="../../eaccpf:description/eaccpf:biogHist/eaccpf:chronList/eaccpf:chronItem[eaccpf:event/text()='Achieved PhD']/eaccpf:date/@standardDate"/>
            </xsl:when>
            <xsl:when test="eaccpf:dateRange">
              <xsl:if test="eaccpf:dateRange/eaccpf:fromDate">
                <xsl:value-of select="eaccpf:dateRange/eaccpf:fromDate/text()"/>
              </xsl:if>
              <xsl:text>-</xsl:text>
              <xsl:if test="eaccpf:dateRange/eaccpf:toDate">
                <xsl:value-of select="eaccpf:dateRange/eaccpf:toDate/text()"/>
              </xsl:if>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        
        <xsl:if test="not($dateInfo='')">
          <xsl:text> (</xsl:text>
          <xsl:value-of select="$dateInfo"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
      </field>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Create fields for the set of selected elements, named according to the 'local-name' and containing the 'text' -->
  <xsl:template match="*" mode="simple_set">
    <xsl:param name="prefix">changeme_</xsl:param>
    <xsl:param name="suffix">_t</xsl:param>

    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="text()"/>
    </field>
  </xsl:template>

    <xsl:variable name="debug" select="false"/>

    <xsl:template name="perform_query" xmlns:encoder="xalan://java.net.URLEncoder">
        <xsl:param name="query"/>
        <xsl:param name="lang">itql</xsl:param>
        <xsl:param name="additional_params"/>
            <!-- FIXME:  Should probably get these as parameters, or sommat -->
        <xsl:param name="HOST">localhost</xsl:param>
        <xsl:param name="PORT">8080</xsl:param>
        <xsl:param name="PROT">http</xsl:param>
        <xsl:param name="URLBASE" select="concat($PROT, '://', $HOST, ':', $PORT, '/')"/>
        <xsl:param name="REPOSITORYNAME" select="'fedora'"/>
        <xsl:param name="RISEARCH" select="concat($URLBASE, 'fedora/risearch',
          '?type=tuples&amp;flush=TRUE&amp;format=Sparql&amp;query=')" />

        <xsl:variable name="encoded_query" select="encoder:encode(normalize-space($query))"/>

        <xsl:variable name="query_url" select="concat($RISEARCH, $encoded_query, '&amp;lang=', $lang,  $additional_params)"/>
        <?xalan-doc-cache-off?>
        <xsl:copy-of select="document($query_url)"/>
        <!-- Doesn't work, as I input this into a variable...  Blargh
        <xsl:comment>
            <xsl:value-of select="$full_query"/>
        </xsl:comment>
        <xsl:copy-of select="$full_query"/>-->
    </xsl:template>

    <xsl:template name="get_ISO8601_date" xmlns:java="http://xml.apache.org/xalan/java">
      <xsl:param name="date"/>

      <xsl:variable name="frac">([.,][0-9]+)</xsl:variable>
      <xsl:variable name="sec_el">(\:[0-9]{2}<xsl:value-of select="$frac"/>?)</xsl:variable>
      <xsl:variable name="min_el">(\:[0-9]{2}(<xsl:value-of select="$frac"/>|<xsl:value-of select="$sec_el"/>))</xsl:variable>
      <xsl:variable name="time_el">([0-9]{2}(<xsl:value-of select="$frac"/>|<xsl:value-of select="$min_el"/>))</xsl:variable>
      <xsl:variable name="time_offset">(Z|[+-]<xsl:value-of select="$time_el"/>)</xsl:variable>
      <xsl:variable name="time_pattern">T<xsl:value-of select="$time_el"/><xsl:value-of select="$time_offset"/>?</xsl:variable>

      <xsl:variable name="day_el">(-[0-9]{2})</xsl:variable>
      <xsl:variable name="month_el">(-[0-9]{2}<xsl:value-of select="$day_el"/>?)</xsl:variable>
      <xsl:variable name="date_el">([0-9]{4}<xsl:value-of select="$month_el"/>?)</xsl:variable>
      <xsl:variable name="date_opt_pattern">(<xsl:value-of select="$date_el"/><xsl:value-of select="$time_pattern"/>?)</xsl:variable>
      <xsl:variable name="pattern">(<xsl:value-of select="$time_pattern"/>|<xsl:value-of select="$date_opt_pattern"/>)</xsl:variable>

      <xsl:if test="$debug">
        <xsl:message>Date to parse: <xsl:value-of select="$date"/></xsl:message>
      </xsl:if>
      <xsl:if test="java:matches(string($date), $pattern)">
        <xsl:if test="$debug">
          <xsl:message>Parsing: <xsl:value-of select="$date"/></xsl:message>
        </xsl:if>
        <!--  XXX: need to add the joda jar to the lib directory to make work? -->
        <xsl:variable name="dp" select="java:org.joda.time.format.ISODateTimeFormat.dateTimeParser()"/>
        <xsl:variable name="parsed" select="java:parseDateTime($dp, $date)"/>

        <xsl:variable name="f" select="java:org.joda.time.format.ISODateTimeFormat.dateTime()"/>
        <xsl:variable name="df" select="java:withZoneUTC($f)"/>
        <xsl:value-of select="java:print($df, $parsed)"/>
      </xsl:if>
    </xsl:template>
</xsl:stylesheet>
