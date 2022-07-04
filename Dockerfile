FROM --platform=linux/arm64 debian:latest


# Setting ENV
ENV TZ=Africa/Cairo
ENV DAEMON_RUN=true
ENV SPARK_VERSION=3.1.2
ENV SCALA_VERSION=2.12.4
ENV HADOOP_VERSION=hadoop3.2
ENV SCALA_HOME=/opt/scala
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-arm64

RUN apt update
RUN apt upgrade --quiet -y
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt install git openjdk-11-jdk golang -y
RUN apt install wget jq curl bc neovim -y
RUN apt install python3 python3-dev python3-pip -y
RUN python3 -m pip install --upgrade pip
RUN pip3 install jedi pylint autopep8 jedi-language-server yapf
RUN pip3 install pytoml awk boto3 delta-spark
RUN pip3 install awswrangler pandas
RUN apt autoremove

WORKDIR /tmp

# Scala installation
RUN wget --no-verbose "https://downloads.typesafe.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz" && \
      tar xzf "scala-${SCALA_VERSION}.tgz" && \
      mkdir "${SCALA_HOME}" -p && \
      rm "/tmp/scala-${SCALA_VERSION}/bin/"*.bat && \
      mv "/tmp/scala-${SCALA_VERSION}/bin" "/tmp/scala-${SCALA_VERSION}/lib" "${SCALA_HOME}" && \
      ln -s "${SCALA_HOME}/bin/"* "/usr/bin/"


# Sbt Installation
RUN  apt update && apt install ca-certificates wget tar && mkdir -p "/usr/local/sbt" && wget -qO - --no-check-certificate "https://github.com/sbt/sbt/releases/download/v1.5.5/sbt-1.5.5.tgz" | tar xz -C /usr/local/sbt --strip-components=1
ENV PATH="${PATH}:/usr/local/sbt/bin"

# Apache Spark
RUN wget --no-verbose https://mirror.klaus-uwe.me/apache/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz && tar -xzf spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz \
      && mv spark-${SPARK_VERSION}-bin-${HADOOP_VERSION} ${SPARK_HOME} \
      && rm spark-${SPARK_VERSION}-bin-${HADOOP_VERSION}.tgz >> /dev/null

# maven
ENV MAVEN_HOME=/opt/maven
RUN wget https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-common/apache-maven-3.6.0-bin.tar.gz
RUN tar xf apache-maven-3.6.0-bin.tar.gz > /dev/null
RUN mv apache-maven-3.6.0 ${MAVEN_HOME}

# node
ENV NODE_HOME=/opt/node
RUN wget https://nodejs.org/dist/v16.14.0/node-v16.14.0-linux-arm64.tar.xz
RUN tar xf node-v16.14.0-linux-arm64.tar.xz > /dev/null
RUN mv node-v16.14.0-linux-arm64 ${NODE_HOME}

# PATH
ENV PATH="${PATH}:${SCALA_HOME}/bin:${JAVA_HOME}/bin"
ENV PATH="${PATH}:${SPARK_HOME}/bin"
ENV PATH="${PATH}:${MAVEN_HOME}/bin"
ENV PATH="${PATH}:${NODE_HOME}/bin"

# Install Awscli
RUN apt install unzip -y
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip > /dev/null
RUN ./aws/install > /dev/null

# # # Build HUDI
# RUN echo "# Checkout Hudi code and build"
# RUN git clone https://github.com/apache/hudi.git
# RUN cd hudi && mvn clean package -DskipTests -Dspark3
# RUN mv hudi/packaging /opt/hudi
## Alternative - grab jars
RUN mkdir /opt/hudi
RUN wget https://repo1.maven.org/maven2/org/apache/hudi/hudi-spark-bundle_2.12/0.9.0/hudi-spark-bundle_2.12-0.9.0.jar -O /opt/hudi/hudi-spark-bundle_2.12-0.9.0.jar
RUN wget https://repo1.maven.org/maven2/org/apache/spark/spark-avro_2.12/2.4.4/spark-avro_2.12-2.4.4.jar -O /opt/hudi/spark-avro_2.12-2.4.4.jar
RUN echo "# Documentation" >> /opt/hudi/readme.md
RUN echo "http://hudi.apache.org/docs/quick-start-guide" >> /opt/hudi/readme.md
RUN echo "# Run command" >> /opt/hudi/readme.md
RUN echo "spark-shell" >> /opt/hudi/readme.md
RUN echo "  --jars \`ls packaging/hudi-spark-bundle/target/hudi-spark-bundle_2.12-*.*.*-SNAPSHOT.jar\` " >> /opt/hudi/readme.md
RUN echo "  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer'"  >> /opt/hudi/readme.md

## Build DELTA
# RUN mkdir /opt/delta
# RUN echo "# Checkout Delta code and build"
# RUN git clone https://github.com/delta-io/delta.git
# RUN cd delta && build/sbt package
# RUN mv delta/target/scala-2.12/*.jar /opt/delta/
# RUN echo "# Run command" >> /opt/delta/readme.md
# RUN echo "spark-submit --packages io.delta:delta-core_2.12:1.0.0 PATH/TO/EXAMPLE" >> /opt/delta/readme.md

## Alternative - grab jars
RUN mkdir /opt/delta
RUN wget https://repo1.maven.org/maven2/io/delta/delta-core_2.12/1.0.0/delta-core_2.12-1.0.0.jar -O /opt/delta/delta-core_2.12-1.0.0.jar
RUN echo "# Documentation" >> /opt/delta/readme.md
RUN echo "https://docs.delta.io/latest/index.html" >> /opt/delta/readme.md

# Install jupyter lab (assuming python3 and pip3 already installed)
RUN pip3 install jupyterlab

# Hive schema gen
RUN echo "# Downloading Hive SerDe schema generator"
RUN git clone https://github.com/strelec/hive-serde-schema-gen.git /opt/hive-serde-schema-gen


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

# Prompt
# RUN echo "# Setting Prompt" >> ~/.bashrc
# RUN echo 'PS1="\\u@\\h \\t:\\$ "' >> ~/.bashrc
# History
RUN echo "# History" >> ~/.bashrc
RUN echo "# avoid duplicates.." >> ~/.bashrc
RUN echo "export HISTCONTROL=ignoredups:erasedups:ignoreboth" >> ~/.bashrc
RUN echo "export HISTSIZE=5000" >> ~/.bashrc
RUN echo "export HISTFILESIZE=10000" >> ~/.bashrc
RUN echo "# append history entries + discard null & case insensitive.." >> ~/.bashrc
RUN echo "shopt -s histappend nullglob histappend #nocaseglob" >> ~/.bashrc
RUN echo "# After each command, save and reload history" >> ~/.bashrc
RUN echo 'export PROMPT_COMMAND=\"history -a; history -c; history -r; $PROMPT_COMMAND\"' >> ~/.bashrc
RUN echo "# search history - Up arrow" >> ~/.bashrc
RUN echo 'bind "\"\e[A\": history-search-backward"' >> ~/.bashrc
RUN echo "# search history - Down arrow" >> ~/.bashrc
RUN echo 'bind "\"\e[B\": history-search-forward"' >> ~/.bashrc
RUN echo "# search history - Right arrow" >> ~/.bashrc
RUN echo 'bind "\"\e[1;5C\":forward-word"' >> ~/.bashrc
RUN echo "# search history - Left arrow" >> ~/.bashrc
RUN echo 'bind "\"\e[1;5D\":backward-word"' >> ~/.bashrc
RUN echo "# Auto Completion" >> ~/.bashrc
RUN echo 'bind "set completion-ignore-case on"' >> ~/.bashrc
# Aliases
RUN echo "# More aliases" >> ~/.bashrc
RUN echo 'alias md="mkdir"' >> ~/.bashrc
RUN echo 'alias rd="rmdir"' >> ~/.bashrc
RUN echo "# Neovim" >> ~/.bashrc
RUN echo "alias vim=nvim" >> ~/.bashrc
RUN echo "alias vi=nvim" >> ~/.bashrc

# Sane vim
RUN mkdir -p ~/.config/nvim/{swap,undo}
RUN wget https://gist.githubusercontent.com/mgabs/9db154d8b8a90575e4ec923993fd66a9/raw/89bfd204bc5cf3094ce5dc7ad43efaa56da31761/gistvim.txt -O ~/.config/nvim/init.vim
RUN sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
RUN echo "# First Boot" >> ~/README.md
RUN echo "Run `nvim +PlugInstall +qall --headless` on first boot">> ~/README.md
RUN echo "And inside nvim 'CocInstall coc-json coc-tsserver coc-jedi'">> ~/README.md


# Cleanup
RUN rm -rf "/tmp/"*

WORKDIR /root

# Declare port used by jupyter-lab
EXPOSE 8888

# Set default command
CMD ["jupyter", "lab", "--port=8888", "--no-browser", "--ip=0.0.0.0", "--allow-root", "--ServerApp.token=''", "--ServerApp.password=''"]
