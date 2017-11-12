FROM monostream/nodejs-gulp-bower
COPY ./run-gulp.sh /
RUN chmod a+x /run-gulp.sh \
    && mkdir -p /wordpress/wp-content/themes/

WORKDIR /wordpress/wp-content/themes
CMD ["/run-gulp.sh"]
