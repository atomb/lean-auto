(set-option :produce-proofs true)
(declare-sort |smti_0| 0)
(declare-fun |smti_1| (|smti_0|) |Bool|)
(declare-fun |smti_2| () |Bool|)
(assert (|not| (|xor| (exists ((|smtd_1| |smti_0|)) (|and| (|smti_1| |smtd_1|) |smti_2|)) (|and| (exists ((|smtd_3| |smti_0|)) (|smti_1| |smtd_3|)) |smti_2|))))
(check-sat)
(get-model)