const ERR = require('async-stacktrace');
const async = require('async');
const express = require('express');
const router = express.Router();
const debug = require('debug')('prairielearn:parameterSelection');

const sqldb = require('../../lib/sqldb');
const sqlLoader = require('../../lib/sql-loader');

const sql = sqlLoader.loadSqlEquiv(__filename);

router.get('/', function(req, res, next) {
    debug('GET /');
    async.series([
        function(callback) {
            const params = {
                assessment_id: res.locals.assessment.id,
                num_sds: 1,
                num_buckets: 30,
            };

            if (req.query.num_sds) {
                params.num_sds = req.query.num_sds;
            }

            if (req.query.num_buckets) {
                params.num_buckets = req.query.num_buckets;
            }
            
            res.locals.num_buckets = params.num_buckets;
            res.locals.num_sds = params.num_sds;

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
module.exports = router;
