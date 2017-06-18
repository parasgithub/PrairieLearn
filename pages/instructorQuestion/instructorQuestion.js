var ERR = require('async-stacktrace');
var _ = require('lodash');
var express = require('express');
var router = express.Router();

var async = require('async');
var error = require('../../lib/error');
var question = require('../../lib/question');
var sqldb = require('../../lib/sqldb');
var sqlLoader = require('../../lib/sql-loader');

var sql = sqlLoader.loadSqlEquiv(__filename);

function processSubmission(req, res, callback) {
    let variant_id, submitted_answer;
    if (res.locals.question.type == 'Freeform') {
        variant_id = req.body.__variant_id;
        submitted_answer = _.omit(req.body, ['__action', '__csrf_token', '__variant_id']);
    } else {
        if (!req.body.postData) return callback(error.make(400, 'No postData', {locals: res.locals, body: req.body}));
        let postData;
        try {
            postData = JSON.parse(req.body.postData);
        } catch (e) {
            return callback(error.make(400, 'JSON parse failed on body.postData', {locals: res.locals, body: req.body}));
        }
        variant_id = postData.variant ? postData.variant.id : null;
        submitted_answer = postData.submittedAnswer;
    }
    const submission = {
        variant_id: variant_id,
        auth_user_id: res.locals.authn_user.user_id,
        submitted_answer: submitted_answer,
    };
    sqldb.callOneRow('variants_ensure_question', [submission.variant_id, res.locals.question.id], (err, result) => {
        if (ERR(err, callback)) return;
        const variant = result.rows[0];
        if (req.body.__action == 'grade') {
            question.saveAndGradeSubmission(submission, variant, res.locals.question, res.locals.course, (err) => {
                if (ERR(err, callback)) return;
                callback(null, submission.variant_id);
            });
        } else if (req.body.__action == 'save') {
            question.saveSubmission(submission, variant, res.locals.question, res.locals.course, (err) => {
                if (ERR(err, callback)) return;
                callback(null, submission.variant_id);
            });
        } else {
            callback(error.make(400, 'unknown __action', {locals: res.locals, body: req.body}));
        }
    });
}

router.post('/', function(req, res, next) {
    if (req.body.__action == 'grade' || req.body.__action == 'save') {
        processSubmission(req, res, function(err, variant_id) {
            if (ERR(err, next)) return;
            res.redirect(res.locals.urlPrefix + '/question/' + res.locals.question.id
                         + '/?variant_id=' + variant_id);
        });
    } else if (req.body.__action == 'test_once') {
        const count = 1;
        const showDetails = true;
        question.startTestQuestion(count, showDetails, res.locals.question, res.locals.course, res.locals.authn_user.user_id, (err, job_sequence_id) => {
            if (ERR(err, next)) return;
            res.redirect(res.locals.urlPrefix + '/jobSequence/' + job_sequence_id);
        });
    } else if (req.body.__action == 'test_100') {
        const count = 100;
        const showDetails = false;
        question.startTestQuestion(count, showDetails, res.locals.question, res.locals.course, res.locals.authn_user.user_id, (err, job_sequence_id) => {
            if (ERR(err, next)) return;
            res.redirect(res.locals.urlPrefix + '/jobSequence/' + job_sequence_id);
        });
    } else {
        return next(new Error('unknown __action: ' + req.body.__action));
    }
});

router.get('/', function(req, res, next) {
    async.series([
        (callback) => {
            sqldb.query(sql.assessment_question_stats, {question_id: res.locals.question.id}, function(err, result) {
                if (ERR(err, next)) return;
                res.locals.assessment_stats = result.rows;
                callback(null);
            });
        },
        (callback) => {
            sqldb.query(sql.question_statistics, {question_id: res.locals.question.id}, function(err, result) {
                if (ERR(err, next)) return;
                let question_stats = [];
                question_stats.push({
                    domain_code: 'exams',
                    domain_name: 'exams',
                    stats: result.rows.filter(function (row) {
                        return row.domain === 'Exams';
                    })[0]
                });
                question_stats.push({
                    domain_code: 'practice_exams',
                    domain_name: 'practice exams',
                    stats: result.rows.filter(function (row) {
                        return row.domain === 'PracticeExams';
                    })[0]
                });
                question_stats.push({
                    domain_code: 'hws',
                    domain_name: 'homeworks',
                    stats: result.rows.filter(function (row) {
                        return row.domain === 'HWs';
                    })[0]
                });

                res.locals.question_stats = question_stats;
                callback(null);
            });
        },
        (callback) => {
            sqldb.query(sql.select_histograms, {question_id: res.locals.question.id}, function(err, result) {
                if (ERR(err, next)) return;

                res.locals.question_attempts_histogram = result.rows[0].question_attempts_histogram;
                res.locals.question_attempts_before_giving_up_histogram = result.rows[0].question_attempts_before_giving_up_histogram;
                res.locals.question_attempts_histogram_hw = result.rows[0].question_attempts_histogram_hw;
                res.locals.question_attempts_before_giving_up_histogram_hw = result.rows[0].question_attempts_before_giving_up_histogram_hw;
                callback(null);
            });
        },
        (callback) => {
            // req.query.variant_id might be undefined, which will generate a new variant
            question.getAndRenderVariant(req.query.variant_id, res.locals, function(err) {
                if (ERR(err, next)) return;
                res.render(__filename.replace(/\.js$/, '.ejs'), res.locals);
                callback(null);
            });
        }
    ]);
});

module.exports = router;
