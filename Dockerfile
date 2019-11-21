FROM alfresco/alfresco-content-repository:${acs.version}

COPY target/amps/*.amp /usr/local/tomcat/amps/

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
  /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup -force

CMD ["catalina.sh", "run"]