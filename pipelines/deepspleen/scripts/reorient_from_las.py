#!/usr/bin/env python
from __future__ import print_function
import argparse
import nibabel as nib
from nibabel.orientations import io_orientation, axcodes2ornt, ornt_transform, aff2axcodes

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--las_seg', required=True)
    p.add_argument('--orig_img', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()

    orig = nib.load(args.orig_img)
    seg_las = nib.load(args.las_seg)

    orig_ax = aff2axcodes(orig.affine)
    seg_ax = aff2axcodes(seg_las.affine)

    orig_ornt = io_orientation(orig.affine)
    seg_ornt = io_orientation(seg_las.affine)
    inv_xform = ornt_transform(seg_ornt, orig_ornt)

    seg_orig = seg_las.as_reoriented(inv_xform)
    nib.save(seg_orig, args.output)

    out_ax = aff2axcodes(seg_orig.affine)
    print('seg_input_axcodes:', ''.join(seg_ax))
    print('restored_axcodes:', ''.join(out_ax))
    print('target_orig_axcodes:', ''.join(orig_ax))

if __name__ == '__main__':
    main()
