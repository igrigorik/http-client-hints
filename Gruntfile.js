'use strict';

module.exports = function(grunt) {
  grunt.initConfig({
    exec: {
      clean: 'rm -rf ./build',
      build: 'mkdir -p ./build && make update'
    },

    'gh-pages': {
      options: {
        base: 'build'
      },
      src: ['index.html']
    },

    watch: {
      files: '*.md',
      tasks: ['exec:build']
    }
  });

  grunt.loadNpmTasks('grunt-exec');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-gh-pages');

  grunt.registerTask('default', ['watch']);
};
