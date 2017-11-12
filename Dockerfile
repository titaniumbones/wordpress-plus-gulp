FROM monostream/nodejs-gulp-bower
COPY ./run-gulp.sh /
RUN chmod a+x /run-gulp.sh \
    && mkdir /active-project

WORKDIR /themes
CMD ["/run-gulp.sh"]
