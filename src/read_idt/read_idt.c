/*
 * =====================================================================================
 *
 *       Filename:  read_idt.c
 *
 *    Description:  Decode PHI .idt file to stdout
 *                  The output is a csv:
 *                  author_id, book_id, block_no, author, book, [level_id, level,... ]
 *          usage:  ./read_idt <file.idt>
 *
 *        Version:  1.0
 *        Created:  11/21/2009 09:31:37 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  proteus  (c)
 *
 * =====================================================================================
 */
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <unistd.h>
#define INFILE "./phi5/lat9999.idt"  /* default input file */
#define MAXIDTSIZE 0xF800            /* Largest idt file */

/* Error macro */
#define error_return(msg) \
        do { perror(msg); exit(EXIT_FAILURE); } while (0)

/* variables */
unsigned char idt_buffer[MAXIDTSIZE];
int pos, in_count;
char author_id[64];
char author[256];
char book[256];
char book_id[64];
int level_id;
char level[256];
int  block_no,  char_count, scanning;
int filein_handle;
int i, j;

/* ----------------------------------------------------------------------- */
int main(int argc, char *argv[])
{
  /* filein_handle = open(INFILE, O_RDONLY); */
  filein_handle = open(argv[1], O_RDONLY);
  if (filein_handle < 0) error_return("Input file error ");
  in_count = read(filein_handle, idt_buffer, sizeof(idt_buffer));
  if (in_count < 0) error_return(".IDT Read file error ");
  close(filein_handle);
  pos = 0;
  scanning = 1;
  while ((pos < in_count) && (scanning == 1) )
  {
    /* ----------------------------------------------- */
    /* Look for "Author entry" :  01 xx xx xx xx EF 80 */
    /* ----------------------------------------------- */
    if (idt_buffer[pos] == 0x01 &&                /* new author code */
        idt_buffer[pos+5] == 0xef && idt_buffer[pos+6] == 0x80)
    {
      pos += 6;                /* advance pos to start of FF terminated id string */
      i = 0;                   /* id string counter */
      while (idt_buffer[pos++] != 0xFF) author_id[i++] = idt_buffer[pos] & 0x7f;
      author_id[i-1]= '\0';                           /* terminate string */
      pos = pos + 2 ;
      char_count = idt_buffer[pos++];
      j = 0;                                        /* title string counter */
      while (char_count--) author[j++] = idt_buffer[pos++];
      author[j]= '\0';                     /* terminate string */
      /*printf("Author ID: %s  Author: %s\n", author_id, author);*/
    }
    /* ----------------------------------------------- */
    /* Look for "New book" :  02 xx xx xx xx EF 81 */
    /* ----------------------------------------------- */
    if (idt_buffer[pos] == 0x02 &&                /* new book code */
        idt_buffer[pos+5] == 0xef && idt_buffer[pos+6] == 0x81)
    {
      /* first collect the block number */
      block_no = 256 * idt_buffer[pos + 3] + idt_buffer[pos + 4];
      pos += 6;                /* advance pos to start of FF terminated id string */
      i = 0;                   /* id string counter */
      while (idt_buffer[pos++] != 0xFF) book_id[i++] = idt_buffer[pos] & 0x7f;
      book_id[i-1]= '\0';                           /* terminate string */
      pos = pos + 2 ;
      char_count = idt_buffer[pos++];
      j = 0;                   /* title string counter */
      while (char_count--) book[j++] = idt_buffer[pos++];
      book[j]= '\0';                      /* terminate string */
      /*printf("Book: %s   Block: %d  Title: %s\n", book_id, block_no, book);
      printf("%s, %s, %s, %d, %s, ", author_id, author, book_id, block_no, book); */
      printf("%s|%s|%d|%s|%s|", author_id, book_id, block_no, author, book);
      /* ----------------------------------------------- */
      /* Look for "New Section Description Label" : 0x11 */
      /* ----------------------------------------------- */
      while (idt_buffer[pos] == 0x11)
      {
        level_id =   idt_buffer[++pos];
        char_count = idt_buffer[++pos];
        pos++;
        j = 0;                   /* string counter */
        while (char_count--) level[j++] = idt_buffer[pos++];
        level[j]= '\0';                      /* terminate string */
        /* printf("Level_id: %d   Label: %s\n", level_id, level); */
        printf("%d|%s|", level_id, level);
      } /* end while levels */
      printf("\n");
    } /* end if book */
    if(pos++ >= in_count) scanning = 0;         /* advance ptr, exit if EOF */
  } /* end while pos */
  exit(EXIT_SUCCESS);
}
