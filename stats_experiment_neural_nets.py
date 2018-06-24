import subprocess
import sys

num_exams = sys.argv[1]
num_sds = sys.argv[2]
output_filename = '\'/Users/psud/PrairieLearn/' + sys.argv[3] + '\''

p1 = subprocess.Popen(
    ['psql', '-d', 'postgres', '-f', 'code/sprocs/stats_experiment_neural_nets.sql',
     '-v', 'num_exams=' + num_exams,
     '-v', 'num_sds=' + num_sds,
     '-v', 'disqualification_threshold=0',
     '-v', 'output_filename=' + output_filename]
)

p1.wait()