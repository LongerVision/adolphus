#!/usr/bin/env python

import sys
from optparse import OptionParser

from adolphus import Experiment, Controller


def main():
    parser = OptionParser()
    parser.add_option('-s', '--socket', dest='socket', default=False,
        action='store_true', help='enable socket controller')
    parser.add_option('-p', '--port', dest='port', default=0, type=int,
        help='port for the socket controller to listen on')
    parser.add_option('-c', '--conf', dest='conf', default=None, 
        help='custom configuration file to load')
    parser.add_option('-z', '--zoom', dest='zoom', default=False,
        action='store_true', help='disable camera view and use visual zoom')

    opts, args = parser.parse_args()

    experiment = Experiment(zoom=opts.zoom)
    if args:
        experiment.execute('loadmodel %s' % args[0])
    experiment.execute('loadconfig %s' % opts.conf)
    if opts.socket:
        controller = Controller(experiment, port=opts.port)
        print('Listening on port %d.' % controller.port)
        sys.stdout.flush()
        controller.main()
    else:
        experiment.start()
        experiment.join()


if __name__ == '__main__':
    main()
