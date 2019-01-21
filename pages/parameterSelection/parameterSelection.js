const ERR = require('async-stacktrace');
const async = require('async');
const express = require('express');
const router = express.Router();
const debug = require('debug')('prairielearn:parameterSelection');

const sqldb = require('@prairielearn/prairielib/sql-db');
const sqlLoader = require('@prairielearn/prairielib/sql-loader');

const sql = sqlLoader.loadSqlEquiv(__filename);

router.get('/', function(req, res, next) {
    debug('GET /');
    async.series([
        function(callback) {
            const params = {
                assessment_id: res.locals.assessment.id,
                num_sds: 1,
                num_buckets: 30,
                num_exams: 25
            };

            if (res.locals.assessment.num_sds) {
                params.num_sds = res.locals.assessment.num_sds;
            }

            if (req.query.num_sds) {
                params.num_sds = req.query.num_sds;
            }

            if (req.query.num_buckets) {
                params.num_buckets = req.query.num_buckets;
            }
            
            res.locals.num_buckets = params.num_buckets;
            res.locals.num_sds = params.num_sds;
            res.locals.num_exams = params.num_exams;

            sqldb.queryOneRow(sql.generated_assessment_distribution, params, function(err, result) {
                if (ERR(err, callback)) return;

                const data = result.rows[0];

                res.locals.result = data.json;
                res.locals.num_exams_kept = data.num_exams_kept;
                res.locals.sd_before = data.sd_before;
                res.locals.sd_after = data.sd_after;
                res.locals.sd_perc_improvement = data.sd_perc_improvement;
                console.log(data.means);
                console.log(data.sds);

                callback(null);
            });
        },
    ], function(err) {
        if (ERR(err, next)) return;
        debug('render page');
        res.render(__filename.replace(/\.js$/, '.ejs'), res.locals);
    });
});

router.post('/', function(req, res, next) {
    if (!res.locals.authz_data.has_instructor_edit) return next();
    if (req.body.__action === 'update_num_sds_value') {
        let params = {
            assessment_id: res.locals.assessment.id,
            num_sds_value: req.body.num_sds,
        };
        sqldb.queryOneRow(sql.update_num_sds_value, params, function(err, _result) {
            if (ERR(err, next)) return;
            if (req.originalUrl.indexOf('?') === -1) {
                res.redirect(req.originalUrl);
            } else {
                res.redirect(req.originalUrl.substring(0, req.originalUrl.indexOf('?')));
            }
        });
    } else {
        return next(error.make(400, 'unknown __action', {locals: res.locals, body: req.body}));
    }
});
module.exports = router;
