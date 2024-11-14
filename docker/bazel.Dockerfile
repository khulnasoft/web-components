FROM gcc:12.2.0

RUN apt update && apt install -y apt-transport-https curl gnupg
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
RUN mv bazel-archive-keyring.gpg /usr/share/keyrings
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
RUN apt update && apt install bazel

# docker run -it -v ${PWD}:/typosearch bazel_typosearch:latest sh -c "cd /typosearch && bazel build //:search //:typosearch-server //:benchmark //:typosearch-test"
