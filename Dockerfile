FROM ubuntu:latest


# Setting ENV
ENV TZ=Africa/Cairo
ENV DAEMON_RUN=true
ENV SPARK_VERSION=3.1.2
ENV SCALA_VERSION=2.12.4
ENV HADOOP_VERSION=hadoop3.2
ENV SCALA_HOME=/opt/scala
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre

RUN apt update
RUN apt upgrade --quiet -y
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt install openjdk-8-jdk git -y
RUN apt install vim wget jq curl bc -y
RUN apt install python3 python3-dev python3-pip -y
RUN python3 -m pip install --upgrade pip
RUN pip3 install pytoml awk boto3 delta-spark
RUN pip3 install awswrangler pandas

WORKDIR /tmp

# Scala installation
RUN wget --no-verbose "https://downloads.typesafe.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz" && \
      tar xzf "scala-${SCALA_VERSION}.tgz" && \
      mkdir "${SCALA_HOME}" -p && \
      rm "/tmp/scala-${SCALA_VERSION}/bin/"*.bat && \
      mv "/tmp/scala-${SCALA_VERSION}/bin" "/tmp/scala-${SCALA_VERSION}/lib" "${SCALA_HOME}" && \
      ln -s "${SCALA_HOME}/bin/"* "/usr/bin/"


# Sbt Installation
RUN export PATH="/usr/local/sbt/bin:$PATH" &&  apt update && apt install ca-certificates wget tar && mkdir -p "/usr/local/sbt" && wget -qO - --no-check-certificate "https://github.com/sbt/sbt/releases/download/v1.5.5/sbt-1.5.5.tgz" | tar xz -C /usr/local/sbt --strip-components=1


# Apache Spark
RUN wget --no-verbose https://mirror.klaus-uwe.me/apache/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz && tar -xzf spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz \
      && mv spark-${SPARK_VERSION}-bin-${HADOOP_VERSION} ${SPARK_HOME} \
      && rm spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz

# maven
ENV MAVEN_HOME=/opt/maven
RUN wget https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-common/apache-maven-3.6.0-bin.tar.gz
RUN tar xf apache-maven-3.6.0-bin.tar.gz
RUN mv apache-maven-3.6.0 ${MAVEN_HOME}

# node
ENV NODE_HOME=/opt/node
RUN wget https://nodejs.org/dist/v14.17.6/node-v14.17.6-linux-x64.tar.xz
RUN tar xf node-v14.17.6-linux-x64.tar.xz
RUN mv node-v14.17.6-linux-x64 ${NODE_HOME}

# PATH
ENV PATH="${PATH}:${SCALA_HOME}/bin:${JAVA_HOME}/bin"
ENV PATH="${PATH}:${SPARK_HOME}/bin"
ENV PATH="${PATH}:${MAVEN_HOME}/bin"
ENV PATH="${PATH}:${NODE_HOME}/bin"

# Install Awscli
RUN apt install unzip -y
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

# Build HUDI
RUN echo "# Checkout Hudi code and build"
RUN git clone https://github.com/apache/hudi.git
RUN cd hudi && mvn clean package -DskipTests
RUN mv hudi/packaging /opt/hudi
RUN echo "#Run command" >> /opt/hudi/readme.md
RUN echo "spark-2.4.4-bin-hadoop2.7/bin/spark-shell" >> /opt/hudi/readme.md
RUN echo "  --jars \`ls packaging/hudi-spark-bundle/target/hudi-spark-bundle_2.11-*.*.*-SNAPSHOT.jar\` " >> /opt/hudi/readme.md
RUN echo "  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer'"  >> /opt/hudi/readme.md

# Build DELTA
RUN echo "# Checkout Delta code and build"
RUN git clone https://github.com/delta-io/delta.git
RUN cd delta && build/sbt package
RUN mkdir /opt/delta && mv delta/target/scala-2.12/*.jar /opt/delta/
RUN echo "# Run command" >> /opt/delta/readme.md
RUN echo "spark-submit --packages io.delta:delta-core_2.12:0.7.0 PATH/TO/EXAMPLE" >> /opt/delta/readme.md

# # glue 3
# RUN wget https://aws-glue-etl-artifacts.s3.amazonaws.com/release/com/amazonaws/AWSGlueETL/3.0.0/AWSGlueETL-3.0.0.jar

# zeppelin
# ENV ZEPPELIN_HOME=/opt/zeppelin
# RUN wget --no-verbose https://dlcdn.apache.org/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0-bin-all.tgz
# RUN tar xf zeppelin-0.10.0-bin-all.tgz
# RUN mv zeppelin-0.10.0-bin-all ${ZEPPELIN_HOME}
# RUN mkdir /opt/${ZEPPELIN_HOME}/{logs,run}
# RUN export PATH=${PATH}:${ZEPPELIN_HOME}/bin
# start zeppelin
# RUN /opt/zeppelin/bin/zeppelin-daemon.sh start
# EXPOSE 80

# Build Jupyter-Lab
# RUN echo "# Install Miniconda" > /home/install-miniconda.md
# RUN echo "# Install jupyter-lab & findspark" >> /home/install-miniconda.md
# RUN echo "# Run notebook"  >> /home/install-miniconda.md
# RUN echo "enable autoactivate conda"  >> /home/install-miniconda.md
# RUN echo "conda config --set auto_activate_base true"  >> /home/install-miniconda.md
# RUN echo "jupyter-lab"  >> /home/install-miniconda.md



# aliases
ENV PS1="\e[0;33m\t\e[0m \e[0;32m\u@\W # \e[0m"

RUN echo "# Setting Prompt" >> ~/.bashrc
RUN echo '"\e[0;33m 🕐\t\e[0m \e[0;32m\u@\W # \e[0m"' >> ~/.bashrc
RUN echo "# History" >> ~/.bashrc
RUN echo "# avoid duplicates.." >> ~/.bashrc
RUN echo "export HISTCONTROL=ignoredups:erasedups:ignoreboth" >> ~/.bashrc
RUN echo "export HISTSIZE=5000" >> ~/.bashrc
RUN echo "export HISTFILESIZE=10000" >> ~/.bashrc
RUN echo "# append history entries + discard null & case insensitive.." >> ~/.bashrc
RUN echo "shopt -s histappend nullglob histappend #nocaseglob" >> ~/.bashrc
RUN echo "# After each command, save and reload history" >> ~/.bashrc
RUN echo "export PROMPT_COMMAND=\"history -a; history -c; history -r; $PROMPT_COMMAND\"" >> ~/.bashrc
RUN echo "# search history - Up arrow" >> ~/.bashrc
RUN echo "bind '\"\e[A\": history-search-backward'" >> ~/.bashrc
RUN echo "# search history - Down arrow" >> ~/.bashrc
RUN echo "bind '\"\e[B\": history-search-forward'" >> ~/.bashrc
RUN echo "# search history - Right arrow" >> ~/.bashrc
RUN echo "bind '\"\e[1;5C\":forward-word'" >> ~/.bashrc
RUN echo "# search history - Left arrow" >> ~/.bashrc
RUN echo "bind '\"\e[1;5D\":backward-word'" >> ~/.bashrc
RUN echo "# Auto Completion" >> ~/.bashrc
RUN echo "bind 'set completion-ignore-case on'" >> ~/.bashrc
RUN echo "# More aliases" >> ~/.bashrc
RUN echo "alias md='mkdir'" >> ~/.bashrc
RUN echo "alias rd='rmdir'" >> ~/.bashrc
# Sane vim
RUN wget https://raw.github.com/gacha/vim-tiny/master/.vimrc -O ~/.vimrc && mkdir -p ~/.vim/swap && mkdir ~/.vim/undo


# Cleanup
RUN rm -rf "/tmp/"*

WORKDIR /root

# Install jupyter lab (assuming python3 and pip3 already installed)
RUN pip3 install jupyterlab

# Declare port used by jupyter-lab
EXPOSE 8888

# Set default command
CMD ["jupyter", "lab", "--port=8888", "--no-browser", "--ip=0.0.0.0", "--allow-root", "--ServerApp.token=''", "--ServerApp.password=''"]

# Artifacts
# https://aws-glue-etl-artifacts.s3.amazonaws.com/
