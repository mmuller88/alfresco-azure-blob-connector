FROM alfresco/alfresco-content-repository:${acs.version}

USER root

COPY target/amps/*.amp /usr/local/tomcat/amps/

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
  /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup -force

## All files in the tomcat folder must be owned by root user and Alfresco group as mentioned in the parent Dockerfile
RUN chgrp -R Alfresco /usr/local/tomcat && \
  find /usr/local/tomcat/webapps -type d -exec chmod 0750 {} \; && \
  find /usr/local/tomcat/webapps -type f -exec chmod 0640 {} \; && \
  find /usr/local/tomcat/shared -type d -exec chmod 0750 {} \; && \
  find /usr/local/tomcat/shared -type f -exec chmod 0640 {} \; && \
  chmod -R g+r /usr/local/tomcat/webapps

#Use the alfresco user
USER alfresco

